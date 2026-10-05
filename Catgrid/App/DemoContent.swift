#if DEBUG
import Foundation
import NonogramKit

/// App Store ekran görüntüleri için örnek ilerleme (yalnızca Debug, `-screenshots` ile açılınca).
///
/// Eğitim ve ilk 4 tür bitmiş (kartları koleksiyonda), ilk türün Altın Kartı kazanılmış,
/// 5. türün zor bölümü yarıya kadar çözülmüş olarak açılır. Veriler bellekte tutulur,
/// gerçek ilerlemeye dokunulmaz.
enum DemoContent {
    static var isEnabled: Bool {
        ProcessInfo.processInfo.arguments.contains("-screenshots")
    }

    @MainActor
    static func seed(_ model: AppModel) {
        let catalog = model.catalog
        let breeds = catalog.chapters.filter { $0.kind == .breed }
        let now = Date()
        func complete(_ puzzle: Puzzle) {
            model.record(PuzzleCompletion(puzzleID: puzzle.id, completedAt: now, elapsed: 120, mistakes: 0))
        }
        catalog.chapters.first { $0.kind == .tutorial }?.puzzles.forEach(complete)
        breeds.prefix(4).forEach { $0.puzzles.forEach(complete) }
        breeds.first?.premiumPuzzles.forEach(complete)

        guard breeds.count > 4 else { return }
        let current = breeds[4]
        current.puzzles.prefix(12).forEach(complete)
        let target = current.puzzles[min(12, current.puzzles.count - 1)]
        var game = NonogramGame(puzzle: target, rules: catalog.rules(for: target))
        // Dolu karelerin yaklaşık %60'ı: oynanmakta olan bir tahta
        for (index, position) in target.solution.positions.filter({ target.solution[$0] }).enumerated() where index % 5 < 3 {
            game.mark(.filled, at: position)
        }
        model.progress.saveGame(game.snapshot)
    }
}
#endif
