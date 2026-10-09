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
/// - Bölüm içinde: bir bulmaca, kendisi veya bölümdeki bir önceki bulmaca çözülmüşse açıktır.
/// - Eğitim (ilk bölüm) her zaman açıktır; ilk kedi türü eğitimin tamamı bitince açılır.
/// - Sonraki kedi türleri, bir önceki tür açıkken onun bulmacalarının **yarısı** çözülünce açılır:
///   oyuncu zorlandığı bir türde takılıp kalmaz, yeni bir kediye geçebilir.
/// - Bir türden tek bir bulmaca bile çözülmüşse o tür açık kalır (kural değişse de ilerleme kilitlenmez).
public struct Progression: Sendable {
    /// Sonraki türü açmak için bir önceki türde çözülmesi gereken oran.
    public static let unlockFraction = 0.5

    public let catalog: LevelCatalog
    public let completedIDs: Set<String>
    /// Oyuncu eğitimi atladıysa ilk kedi türü eğitim bitmeden açılır.
    public let tutorialSkipped: Bool

    public init(catalog: LevelCatalog, completedIDs: Set<String>, tutorialSkipped: Bool = false) {
        self.catalog = catalog
        self.completedIDs = completedIDs
        self.tutorialSkipped = tutorialSkipped
    }

    public func isCompleted(_ puzzleID: String) -> Bool {
        completedIDs.contains(puzzleID)
    }

    public func isUnlocked(_ puzzleID: String) -> Bool {
        guard let chapter = catalog.chapter(containing: puzzleID),
              let index = chapter.puzzles.firstIndex(where: { $0.id == puzzleID })
        else { return false }
        if isCompleted(puzzleID) { return true }
        if index == 0 { return isUnlocked(chapter) }
        return isCompleted(chapter.puzzles[index - 1].id)
    }

    public func isUnlocked(_ chapter: Chapter) -> Bool {
        guard let index = playableChapters.firstIndex(where: { $0.id == chapter.id }) else { return false }
        if index == 0 || chapter.puzzles.contains(where: { isCompleted($0.id) }) { return true }
        let previous = playableChapters[index - 1]
        if previous.kind == .tutorial && tutorialSkipped { return true }
        guard isUnlocked(previous) else { return false }
        return completedCount(in: previous) >= requiredCount(toUnlockAfter: previous)
    }

    /// `chapter` bölümünden sonra gelen türü açmak için çözülmesi gereken bulmaca sayısı.
    /// Eğitimin tamamı gerekir; kedi türlerinde yarısı (yukarı yuvarlanır).
    public func requiredCount(toUnlockAfter chapter: Chapter) -> Int {
        if chapter.kind == .tutorial { return chapter.puzzles.count }
        return Int((Double(chapter.puzzles.count) * Self.unlockFraction).rounded(.up))
    }

    /// Kilitli bir türün kilidini açan bir önceki tür.
    public func unlockingChapter(for chapter: Chapter) -> Chapter? {
        guard let index = playableChapters.firstIndex(where: { $0.id == chapter.id }), index > 0 else { return nil }
        return playableChapters[index - 1]
    }

    private var playableChapters: [Chapter] {
        catalog.chapters.filter { !$0.puzzles.isEmpty }
    }

    /// "Devam Et" butonu: ilk açık ve bitmemiş bulmaca.
    public var nextPlayable: Puzzle? {
        catalog.orderedPuzzles.first { puzzle in
            if tutorialSkipped, catalog.chapter(containing: puzzle.id)?.kind == .tutorial { return false }
            return isUnlocked(puzzle.id) && !isCompleted(puzzle.id)
        }
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
