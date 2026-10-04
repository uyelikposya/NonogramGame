import Foundation

/// Bölüm grubu: Eğitim veya bir kedi türü seviyesi.
public struct Chapter: Identifiable, Hashable, Sendable {
    public enum Kind: String, Codable, Sendable {
        case tutorial
        case breed
    }

    public let id: String
    public let kind: Kind
    public let title: LocalizedText
    public let subtitle: LocalizedText?
    /// Bölüm kartı ve kilit ekranında kullanılan vurgu rengi.
    public let accentColor: RGBColor?
    /// İçerik hazırlanırken eksik bölümleri raporlamak için (ör. 30).
    public let expectedPuzzleCount: Int
    public let puzzles: [Puzzle]

    public init(
        id: String,
        kind: Kind,
        title: LocalizedText,
        subtitle: LocalizedText? = nil,
        accentColor: RGBColor? = nil,
        expectedPuzzleCount: Int,
        puzzles: [Puzzle]
    ) {
        self.id = id
        self.kind = kind
        self.title = title
        self.subtitle = subtitle
        self.accentColor = accentColor
        self.expectedPuzzleCount = expectedPuzzleCount
        self.puzzles = puzzles
    }
}

/// Uygulamadaki tüm bölümlerin oynanma sırasına göre dizilmiş hali.
/// Kilit sistemi bu tek, düz sıra üzerinden çalışır.
public struct LevelCatalog: Sendable {
    public static let supportedSchemaVersion = 1

    public let chapters: [Chapter]
    public let defaultRules: GameRules
    /// Eğitim 1-10, ardından 1. tür 1-30, 2. tür 1-30, ...
    public let orderedPuzzles: [Puzzle]
    private let indexByPuzzleID: [String: Int]
    private let chapterIDByPuzzleID: [String: String]

    public init(chapters: [Chapter], defaultRules: GameRules = .classic) throws {
        self.chapters = chapters
        self.defaultRules = defaultRules
        self.orderedPuzzles = chapters.flatMap(\.puzzles)

        var indexes: [String: Int] = [:]
        var chapterIDs: [String: String] = [:]
        for chapter in chapters {
            for puzzle in chapter.puzzles {
                guard indexes[puzzle.id] == nil else { throw CatalogError.duplicatePuzzleID(puzzle.id) }
                indexes[puzzle.id] = indexes.count
                chapterIDs[puzzle.id] = chapter.id
            }
        }
        self.indexByPuzzleID = indexes
        self.chapterIDByPuzzleID = chapterIDs
    }

    public func puzzle(withID id: String) -> Puzzle? {
        index(of: id).map { orderedPuzzles[$0] }
    }

    public func index(of puzzleID: String) -> Int? {
        indexByPuzzleID[puzzleID]
    }

    public func chapter(containing puzzleID: String) -> Chapter? {
        chapterIDByPuzzleID[puzzleID].flatMap { id in chapters.first { $0.id == id } }
    }

    public func puzzle(after puzzleID: String) -> Puzzle? {
        guard let index = index(of: puzzleID), index + 1 < orderedPuzzles.count else { return nil }
        return orderedPuzzles[index + 1]
    }

    public func rules(for puzzle: Puzzle) -> GameRules {
        if let override = puzzle.rulesOverride { return override }
        return chapter(containing: puzzle.id)?.kind == .tutorial ? .relaxed : defaultRules
    }
}

public enum CatalogError: Error, Equatable {
    case missingResource(String)
    case unsupportedSchema(Int)
    case chapterMismatch(expected: String, found: String)
    case duplicatePuzzleID(String)
}
