import Foundation
import NonogramKit

/// Kedi Bulmaca ekranındaki olaylar (ses ve titreşim).
enum CatEvent: Equatable {
    case crossed
    case cleared
    case found(combo: Int)
    case wrong
    case solved
    case failed
}

/// Tahtanın üstünde kısa süre uçuşan yazılar: "+576", "Bulundu!", "Harika".
struct CatEffect: Identifiable, Equatable {
    enum Kind: Equatable {
        case points(Int)
        case found
        case perfectlyMarked
        case combo(Int)
    }

    let id = UUID()
    let kind: Kind
    let position: GridPosition
}

/// Kedi Bulmaca ekranının durumu: dokunma/sürükleme, puan ve seri, ipucu önizlemesi, zamanlayıcı.
@MainActor
@Observable
final class CatGameViewModel {
    private(set) var game: CatGame
    private(set) var score = 0
    /// Art arda hızlı bulunan kedi sayısı (seri).
    private(set) var combo = 0
    private(set) var bestCombo = 0
    private(set) var perfectlyMarkedCount = 0
    private(set) var usedHints = false
    private(set) var effects: [CatEffect] = []
    /// "?" ipucunun önizlemesi; oyuncu "Uygula"ya basınca tahtaya işlenir.
    private(set) var pendingHint: CatHint?
    /// Son yanlış kedi denemesi (kısa sallanma için).
    private(set) var lastWrong: GridPosition?
    /// Parmağın altındaki kare.
    private(set) var activeCell: GridPosition?
    private(set) var isPaused = false

    var onEvent: ((CatEvent) -> Void)?
    var onSolved: ((CatPuzzleModel.Completion) -> Void)?

    /// Seri için iki kedi arasındaki en uzun süre.
    static let comboWindow: TimeInterval = 25

    private var lastFindAt: Date?
    private var touchStart: GridPosition?
    private var paintCross: Bool?
    private var timerTask: Task<Void, Never>?
    private let now: () -> Date

    init(level: CatLevel, saved: CatSnapshot? = nil, now: @escaping () -> Date = { Date() }) {
        game = saved.map { CatGame(level: level, restoring: $0) } ?? CatGame(level: level)
        self.now = now
    }

    var level: CatLevel { game.level }
    var isFinished: Bool { game.status != .playing }

    var snapshotToSave: CatSnapshot? {
        game.status == .playing ? game.snapshot : nil
    }

    // MARK: - Dokunma

    /// Dokunma bırakılınca işlenir (kedi kutlaması parmak kalkınca gelir); sürükleme
    /// başka bir kareye geçince X boyamaya döner.
    func touchBegan(at position: GridPosition) {
        guard !isFinished, game.contains(position) else { return }
        dismissHint()
        touchStart = position
        paintCross = nil
        activeCell = position
    }

    func touchMoved(to position: GridPosition) {
        guard !isFinished, let start = touchStart, game.contains(position), position != activeCell else { return }
        activeCell = position
        if paintCross == nil {
            // İlk karenin durumu ne yapılacağını belirler: boşsa X koy, X'liyse sil
            switch game[start] {
            case .blank: paintCross = true
            case .cross: paintCross = false
            default: paintCross = true
            }
            paint(at: start)
        }
        paint(at: position)
    }

    func touchEnded() {
        defer {
            touchStart = nil
            paintCross = nil
            activeCell = nil
        }
        guard let start = touchStart, paintCross == nil, !isFinished else { return }
        handle(game.tap(at: start))
    }

    private func paint(at position: GridPosition) {
        guard let cross = paintCross else { return }
        handle(game.paint(cross: cross, at: position))
    }

    // MARK: - İpuçları

    /// "?" düğmesi: bir sonraki mantık adımını önizler. Adım yoksa `false`.
    @discardableResult
    func previewHint() -> Bool {
        guard !isFinished, let hint = game.hint() else { return false }
        pendingHint = hint
        return true
    }

    func applyHint() {
        guard let hint = pendingHint else { return }
        pendingHint = nil
        usedHints = true
        handle(game.apply(hint))
    }

    func dismissHint() {
        pendingHint = nil
    }

    /// Kedi bulucu: bir kedinin yerini gösterir ve yerleştirir.
    func revealCat() {
        guard !isFinished else { return }
        dismissHint()
        usedHints = true
        handle(game.revealCat())
    }

    /// Kaybedince ödüllü reklamla bir can.
    func revive() {
        game.revive()
        start()
    }

    func restart() {
        stop()
        game = CatGame(level: level)
        score = 0
        combo = 0
        bestCombo = 0
        perfectlyMarkedCount = 0
        usedHints = false
        effects = []
        pendingHint = nil
        lastWrong = nil
        lastFindAt = nil
        isPaused = false
        start()
    }

    // MARK: - Sonuçlar

    private func handle(_ move: CatMove) {
        switch move {
        case .ignored:
            break
        case .crossed:
            onEvent?(.crossed)
        case .cleared:
            onEvent?(.cleared)
        case .found(let find):
            celebrate(find)
            onEvent?(.found(combo: find.revealed ? 0 : combo))
        case .solved(let find):
            celebrate(find)
            stop()
            onEvent?(.solved)
            onSolved?(CatPuzzleModel.Completion(
                level: level,
                score: score,
                mistakes: game.mistakes,
                usedHints: usedHints,
                elapsed: game.elapsed,
                bestCombo: bestCombo,
                perfectlyMarked: perfectlyMarkedCount
            ))
        case .mistake(let position):
            wrong(at: position)
            onEvent?(.wrong)
        case .failed(let position):
            wrong(at: position)
            stop()
            onEvent?(.failed)
        }
    }

    private func wrong(at position: GridPosition) {
        lastWrong = position
        combo = 0
        Task {
            try? await Task.sleep(for: .seconds(0.5))
            if lastWrong == position { lastWrong = nil }
        }
    }

    private func celebrate(_ find: CatFind) {
        var shown: [CatEffect] = [CatEffect(kind: .found, position: find.position)]
        if !find.revealed {
            let time = now()
            if let last = lastFindAt, time.timeIntervalSince(last) <= Self.comboWindow {
                combo += 1
            } else {
                combo = 1
            }
            lastFindAt = time
            bestCombo = max(bestCombo, combo)
            var points = 480 + 96 * (combo - 1)
            if find.perfectlyMarked {
                points += 192
                perfectlyMarkedCount += 1
                shown.append(CatEffect(kind: .perfectlyMarked, position: find.position))
            }
            score += points
            shown.append(CatEffect(kind: .points(points), position: find.position))
            if combo >= 2 {
                shown.append(CatEffect(kind: .combo(combo), position: find.position))
            }
        }
        effects.append(contentsOf: shown)
        let ids = Set(shown.map(\.id))
        Task {
            try? await Task.sleep(for: .seconds(1.4))
            effects.removeAll { ids.contains($0.id) }
        }
    }

    // MARK: - Zamanlayıcı

    func start() {
        guard timerTask == nil, !isFinished, !isPaused else { return }
        timerTask = Task { [weak self] in
            while !Task.isCancelled {
                try? await Task.sleep(for: .seconds(1))
                guard let self, !Task.isCancelled, !self.isFinished else { return }
                self.game.elapsed += 1
            }
        }
    }

    func stop() {
        timerTask?.cancel()
        timerTask = nil
    }

    func pause() {
        guard !isFinished else { return }
        isPaused = true
        stop()
    }

    func resume() {
        isPaused = false
        start()
    }
}
