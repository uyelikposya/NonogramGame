import Foundation
import NonogramKit

/// Oyun ekranının durumu. Kurallar `NonogramGame`'de; burası yalnızca arayüz akışını
/// (seçili araç, sürükleme, zamanlayıcı, bitiş bildirimi) yönetir.
@MainActor
@Observable
final class GameViewModel {
    private(set) var game: NonogramGame
    var tool: MarkTool = .fill
    /// Son hatalı kare; arayüz kısa bir sarsma/kırmızı yanıp sönme animasyonu için kullanır.
    private(set) var lastMistake: GridPosition?

    /// Bulmaca çözülünce çağrılır (ilerleme kaydı, reklam sayacı).
    var onSolved: ((PuzzleCompletion) -> Void)?

    private var dragTarget: CellState?
    private var timerTask: Task<Void, Never>?
    private let now: () -> Date

    init(puzzle: Puzzle, rules: GameRules, now: @escaping () -> Date = { Date() }) {
        self.game = NonogramGame(puzzle: puzzle, rules: rules)
        self.now = now
    }

    var puzzle: Puzzle { game.puzzle }
    var isFinished: Bool { game.status != .playing }

    // MARK: - Dokunma ve sürükleme

    func tap(_ position: GridPosition) {
        handle(game.toggle(at: position, with: tool), at: position)
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
        guard let target = dragTarget, game.board.contains(position) else { return }
        let current = game.board[position]
        // Silerken yalnızca aynı işaretleri, koyarken yalnızca boş kareleri etkile
        let applies = target == .blank ? current == tool.cellState : current == .blank
        guard applies else { return }
        handle(game.mark(target, at: position), at: position)
        if isFinished { dragTarget = nil }
    }

    func dragEnded() {
        dragTarget = nil
    }

    func undo() {
        game.undo()
    }

    // MARK: - Zamanlayıcı

    func start() {
        guard timerTask == nil else { return }
        timerTask = Task { [weak self] in
            while !Task.isCancelled {
                try? await Task.sleep(for: .seconds(1))
                guard let self, !self.isFinished else { return }
                self.game.advanceTime(by: 1)
            }
        }
    }

    func stop() {
        timerTask?.cancel()
        timerTask = nil
    }

    // MARK: - Yardımcılar

    private func handle(_ outcome: NonogramGame.MoveOutcome, at position: GridPosition) {
        switch outcome {
        case .mistake, .failed(.outOfMistakes):
            lastMistake = position
        case .solved:
            stop()
            onSolved?(PuzzleCompletion(
                puzzleID: puzzle.id,
                completedAt: now(),
                elapsed: game.elapsed,
                mistakes: game.mistakes
            ))
        default:
            break
        }
        if case .failed = outcome { stop() }
    }
}
