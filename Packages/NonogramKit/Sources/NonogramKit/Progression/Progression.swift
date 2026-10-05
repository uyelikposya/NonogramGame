import Foundation

/// Bir bulmacanın tamamlanma kaydı. Kalıcı depolama (SwiftData) Aşama 3'te bunu saklayacak.
public struct PuzzleCompletion: Codable, Hashable, Sendable {
    public let puzzleID: String
    public let completedAt: Date
    public let elapsed: TimeInterval
    public let mistakes: Int

    public init(puzzleID: String, completedAt: Date, elapsed: TimeInterval, mistakes: Int) {
        self.puzzleID = puzzleID
        self.completedAt = completedAt
        self.elapsed = elapsed
        self.mistakes = mistakes
    }
}

/// Kilit kuralları. Saf fonksiyonlardır; ilerleme verisi dışarıdan verilir.
///
/// Kural: bir bulmaca, kendisi veya sıradaki bir önceki bulmaca tamamlanmışsa açıktır.
/// "Öncekilerin hepsi" yerine "bir önceki" kullanılır ki ileride araya bölüm eklense
/// oyuncunun daha önce bitirdiği bölümler kilitlenmesin.
public struct Progression: Sendable {
    public let catalog: LevelCatalog
    public let completedIDs: Set<String>

    public init(catalog: LevelCatalog, completedIDs: Set<String>) {
        self.catalog = catalog
        self.completedIDs = completedIDs
    }

    public func isCompleted(_ puzzleID: String) -> Bool {
        completedIDs.contains(puzzleID)
    }

    public func isUnlocked(_ puzzleID: String) -> Bool {
        guard let index = catalog.index(of: puzzleID) else { return false }
        if index == 0 || isCompleted(puzzleID) { return true }
        return isCompleted(catalog.orderedPuzzles[index - 1].id)
    }

    public func isUnlocked(_ chapter: Chapter) -> Bool {
        chapter.puzzles.first.map { isUnlocked($0.id) } ?? false
    }

    /// "Devam Et" butonu: ilk açık ve bitmemiş bulmaca.
    public var nextPlayable: Puzzle? {
        catalog.orderedPuzzles.first { isUnlocked($0.id) && !isCompleted($0.id) }
    }

    /// Premium bulmaca: tür açıldıysa ve (ilkiyse ya da) bir önceki premium bulmaca çözüldüyse açık.
    /// Abonelik kontrolü uygulamadadır; bu yalnızca sıra kuralı.
    public func isPremiumUnlocked(_ puzzleID: String) -> Bool {
        guard let chapter = catalog.chapter(containing: puzzleID),
              let index = chapter.premiumPuzzles.firstIndex(where: { $0.id == puzzleID }),
              isUnlocked(chapter)
        else { return false }
        if index == 0 || isCompleted(puzzleID) { return true }
        return isCompleted(chapter.premiumPuzzles[index - 1].id)
    }

    public func completedPremiumCount(in chapter: Chapter) -> Int {
        chapter.premiumPuzzles.filter { isCompleted($0.id) }.count
    }

    public func completedCount(in chapter: Chapter) -> Int {
        chapter.puzzles.filter { isCompleted($0.id) }.count
    }
}
