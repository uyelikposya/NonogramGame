import Foundation
import NonogramKit

/// Ses ve titreşim için arayüze bildirilen olaylar.
enum GameEvent: Equatable {
    case filled
    case crossed
    case erased
    case mistake
    case lineCompleted
    case solved
    case failed
}

/// Oyun ekranının durumu. Kurallar `NonogramGame`'de; burası yalnızca arayüz akışını
/// (seçili araç, sürükleme, zamanlayıcı, bitiş bildirimi) yönetir.
@MainActor
@Observable
final class GameViewModel {
    private(set) var game: NonogramGame
    var tool: MarkTool = .fill
    /// Son hatalı kare; arayüz kısa bir kırmızı yanıp sönme ve titreşim için kullanır.
    private(set) var lastMistake: GridPosition?
    /// Parmağın altındaki kare; satırı ve sütunu vurgulanır.
    private(set) var activeCell: GridPosition?

    /// Bulmaca çözülünce çağrılır (ilerleme kaydı, reklam sayacı).
    var onSolved: ((PuzzleCompletion) -> Void)?
    /// Her anlamlı hamlede çağrılır (ses efektleri).
    var onEvent: ((GameEvent) -> Void)?

    private let rules: GameRules
    private var dragTarget: CellState?
    private var timerTask: Task<Void, Never>?
    private let now: () -> Date

    /// - Parameter savedGame: Yarım kalan oyun; varsa tahta, hatalar ve süre buradan devam eder.
    init(puzzle: Puzzle, rules: GameRules, savedGame: GameSnapshot? = nil, now: @escaping () -> Date = { Date() }) {
        self.game = savedGame.map { NonogramGame(puzzle: puzzle, rules: rules, restoring: $0) }
            ?? NonogramGame(puzzle: puzzle, rules: rules)
        self.rules = rules
        self.now = now
    }

    var puzzle: Puzzle { game.puzzle }
    var isFinished: Bool { game.status != .playing }

    /// Kaydedilecek yarım oyun. Bitmiş ya da hiç dokunulmamış oyunda `nil`:
    /// o durumda varsa eski kayıt silinmelidir.
    var snapshotToSave: GameSnapshot? {
        guard game.status == .playing else { return nil }
        let hasProgress = game.mistakes > 0 || game.board.storage.contains { $0 != .blank }
        return hasProgress ? game.snapshot : nil
    }

    // MARK: - Dokunma ve sürükleme

    func tap(_ position: GridPosition) {
        guard game.board.contains(position) else { return }
        let target: CellState = game.board[position] == .blank ? tool.cellState : .blank
        handle(game.toggle(at: position, with: tool), at: position, target: target)
    }

    /// Sürüklemenin ilk karesi hedefi belirler: boş kareden başlanırsa aracın işareti
    /// konur, işaretli kareden başlanırsa geçilen aynı işaretler silinir.
    func dragBegan(at position: GridPosition) {
        guard game.board.contains(position) else { return }
        let current = game.board[position]
        dragTarget = current == .blank ? tool.cellState : (current == tool.cellState ? .blank : nil)
        dragMoved(to: position)
    }

    func dragMoved(to position: GridPosition) {
        guard game.board.contains(position) else { return }
        // Aynı karede sürüklerken gözlemcileri boşuna tetikleme
        if !isFinished, activeCell != position { activeCell = position }
        guard let target = dragTarget else { return }
        let current = game.board[position]
        // Silerken yalnızca aynı işaretleri, koyarken yalnızca boş kareleri etkile
        let applies = target == .blank ? current == tool.cellState : current == .blank
        guard applies else { return }
        handle(game.mark(target, at: position), at: position, target: target)
        if isFinished {
            dragTarget = nil
            activeCell = nil
        }
    }

    func dragEnded() {
        dragTarget = nil
        if activeCell != nil { activeCell = nil }
    }

    func undo() {
        game.undo()
    }

    /// Ödüllü reklam karşılığı bir kez devam hakkı (bulmaca başına).
    private(set) var hasRevived = false

    var canRevive: Bool {
        guard !hasRevived, case .lost = game.status else { return false }
        return true
    }

    /// Kaybedilen oyunu +1 pati ya da +60 saniye ile sürdürür.
    func revive() {
        guard canRevive else { return }
        hasRevived = true
        game.revive(extraMistakes: 1, extraTime: 60)
        lastMistake = nil
        start()
    }

    /// Kaybedince "Tekrar Dene": tahtayı sıfırlar.
    func restart() {
        stop()
        game = NonogramGame(puzzle: puzzle, rules: rules)
        lastMistake = nil
        hasRevived = false
        activeCell = nil
        start()
    }

    // MARK: - Zamanlayıcı

    func start() {
        guard timerTask == nil, !isFinished else { return }
        timerTask = Task { [weak self] in
            while !Task.isCancelled {
                try? await Task.sleep(for: .seconds(1))
                guard let self, !Task.isCancelled, !self.isFinished else { return }
                if case .failed = self.game.advanceTime(by: 1) {
                    self.onEvent?(.failed)
                    self.stop()
                }
            }
        }
    }

    func stop() {
        timerTask?.cancel()
        timerTask = nil
    }

    // MARK: - Yardımcılar

    private func handle(_ outcome: NonogramGame.MoveOutcome, at position: GridPosition, target: CellState) {
        switch outcome {
        case .changed:
            if target == .filled, game.isRowSatisfied(position.row) || game.isColumnSatisfied(position.column) {
                onEvent?(.lineCompleted)
            } else {
                onEvent?(target == .filled ? .filled : (target == .crossed ? .crossed : .erased))
            }
        case .mistake:
            lastMistake = position
            onEvent?(.mistake)
        case .failed(.outOfMistakes):
            lastMistake = position
            onEvent?(.failed)
        case .failed(.outOfTime):
            onEvent?(.failed)
        case .solved:
            onEvent?(.solved)
            onSolved?(PuzzleCompletion(
                puzzleID: puzzle.id,
                completedAt: now(),
                elapsed: game.elapsed,
                mistakes: game.mistakes
            ))
        default:
            break
        }
        if isFinished { stop() }
    }
}
