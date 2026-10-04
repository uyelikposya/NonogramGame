import Foundation
import NonogramKit

/// Uygulama genelindeki durum: bölüm kataloğu ve ilerleme.
/// Aşama 3'te ilerleme SwiftData'ya, reklam sayacı `AdService`'e taşınacak.
@MainActor
@Observable
final class AppModel {
    static let completedKey = "progress.completedPuzzleIDs"

    let catalog: LevelCatalog
    private(set) var completedIDs: Set<String> {
        didSet { defaults.set(Array(completedIDs), forKey: Self.completedKey) }
    }

    private let defaults: UserDefaults

    init(catalog: LevelCatalog, defaults: UserDefaults = .standard) {
        self.catalog = catalog
        self.defaults = defaults
        self.completedIDs = Set(defaults.stringArray(forKey: Self.completedKey) ?? [])
    }

    static func live() -> AppModel {
        do {
            return AppModel(catalog: try CatalogLoader.load(from: .main))
        } catch {
            // Paketlenmiş içerik bozuksa geliştirme sırasında hemen fark edilsin
            fatalError("Bölüm kataloğu yüklenemedi: \(error)")
        }
    }

    var progression: Progression {
        Progression(catalog: catalog, completedIDs: completedIDs)
    }

    func record(_ completion: PuzzleCompletion) {
        completedIDs.insert(completion.puzzleID)
    }
}
