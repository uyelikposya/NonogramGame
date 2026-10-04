import Foundation
import NonogramKit

/// Uygulama genelindeki durum: bölüm kataloğu ve oyuncu ilerlemesi.
@MainActor
@Observable
final class AppModel {
    let catalog: LevelCatalog
    let progress: ProgressStore

    init(catalog: LevelCatalog, progress: ProgressStore) {
        self.catalog = catalog
        self.progress = progress
    }

    static func live() -> AppModel {
        do {
            return AppModel(catalog: try CatalogLoader.load(from: .main), progress: try ProgressStore.live())
        } catch {
            // Paketlenmiş içerik veya veritabanı açılamıyorsa geliştirme sırasında hemen fark edilsin
            fatalError("Uygulama başlatılamadı: \(error)")
        }
    }

    var progression: Progression {
        Progression(catalog: catalog, completedIDs: progress.completedIDs)
    }

    @discardableResult
    func record(_ completion: PuzzleCompletion) -> CompletionResult {
        progress.recordCompletion(completion)
    }

    // MARK: - Ekranlar için özetler

    /// Planlanan toplam bulmaca sayısı (içerik henüz tamamlanmamış olsa da 460).
    var plannedPuzzleCount: Int {
        catalog.chapters.map(\.expectedPuzzleCount).reduce(0, +)
    }

    var completedCount: Int {
        let completed = progress.completedIDs
        return catalog.orderedPuzzles.filter { completed.contains($0.id) }.count
    }

    func chapter(withID id: String) -> Chapter? {
        catalog.chapters.first { $0.id == id }
    }

    /// Bölüm içindeki 1'den başlayan sıra numarası.
    func number(of puzzle: Puzzle) -> Int {
        (catalog.chapter(containing: puzzle.id)?.puzzles.firstIndex(of: puzzle) ?? 0) + 1
    }

    func nextPuzzle(after puzzle: Puzzle) -> Puzzle? {
        catalog.puzzle(after: puzzle.id)
    }

    /// Ana ekrandaki "Devam Et" hedefi: önce en son yarım bırakılan açık bulmaca, yoksa sıradaki.
    var resumablePuzzle: Puzzle? {
        let progression = progression
        let inProgress = catalog.orderedPuzzles
            .filter { progress.hasSavedGame(for: $0.id) && progression.isUnlocked($0.id) }
            .max { (progress.record(for: $0.id)?.lastPlayedAt ?? .distantPast) < (progress.record(for: $1.id)?.lastPlayedAt ?? .distantPast) }
        return inProgress ?? progression.nextPlayable
    }

    /// Ayarlardan ilerleme sıfırlanır.
    func resetProgress() {
        progress.resetAll()
    }
}
