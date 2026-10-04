import Foundation
import Testing
@testable import NonogramKit

struct PuzzleDecodingTests {
    func decode(_ json: String) throws -> Puzzle {
        try JSONDecoder().decode(Puzzle.self, from: Data(json.utf8))
    }

    @Test func decodesArtworkAndClues() throws {
        let puzzle = try decode("""
        {
          "id": "paw", "title": { "en": "Paw", "tr": "Pati" },
          "palette": { "a": "#4A3B35", "b": "f2d7c9" },
          "pixels": ["a.a", ".b.", "bbb"]
        }
        """)
        #expect(puzzle.rows == 3 && puzzle.columns == 3)
        #expect(puzzle.rowClues == [[1, 1], [1], [3]])
        #expect(puzzle.columnClues == [[1, 1], [2], [1, 1]])
        #expect(puzzle.artwork[0, 0] == RGBColor(red: 0x4A, green: 0x3B, blue: 0x35))
        #expect(puzzle.artwork[0, 1] == nil)
        #expect(puzzle.title.resolved(preferredLanguages: ["tr-TR"]) == "Pati")
        #expect(puzzle.rulesOverride == nil)
    }

    @Test func decodesRulesOverride() throws {
        let puzzle = try decode("""
        { "id": "boss", "title": { "en": "Boss" }, "palette": { "a": "#000000" },
          "pixels": ["a"], "rules": { "mistakeLimit": null, "timeLimitSeconds": 120 } }
        """)
        #expect(puzzle.rulesOverride == GameRules(mistakeLimit: nil, timeLimit: 120))
    }

    @Test func rejectsInvalidContent() {
        #expect(throws: DecodingError.self) {
            try decode(#"{ "id": "x", "title": {}, "palette": { "a": "#000000" }, "pixels": ["ab"] }"#)
        }
        #expect(throws: DecodingError.self) {
            try decode(#"{ "id": "x", "title": {}, "palette": { "a": "#000000" }, "pixels": ["aa", "a"] }"#)
        }
        #expect(throws: DecodingError.self) {
            try decode(#"{ "id": "x", "title": {}, "palette": { "a": "red" }, "pixels": ["a"] }"#)
        }
        #expect(throws: DecodingError.self) {
            try decode(#"{ "id": "x", "title": {}, "palette": { "a": "#000000" }, "pixels": ["..."] }"#)
        }
    }
}

struct CatalogTests {
    static let catalogJSON = """
    {
      "schemaVersion": 1,
      "chapters": [
        { "id": "tutorial", "kind": "tutorial", "title": { "en": "School" }, "file": "tutorial", "expectedPuzzleCount": 2 },
        { "id": "siamese", "kind": "breed", "title": { "en": "Siamese" }, "file": "siamese", "expectedPuzzleCount": 2 },
        { "id": "persian", "kind": "breed", "title": { "en": "Persian" }, "file": "persian", "expectedPuzzleCount": 30 }
      ]
    }
    """

    static func chapter(_ id: String, puzzles: [String]) -> String {
        let items = puzzles.map {
            #"{ "id": "\#($0)", "title": { "en": "P" }, "palette": { "a": "#000000" }, "pixels": ["a."] }"#
        }
        return #"{ "schemaVersion": 1, "chapterID": "\#(id)", "puzzles": [\#(items.joined(separator: ","))] }"#
    }

    func load(files: [String: String]) throws -> LevelCatalog {
        try CatalogLoader.load(catalogData: Data(Self.catalogJSON.utf8)) { files[$0].map { Data($0.utf8) } }
    }

    func sampleCatalog() throws -> LevelCatalog {
        try load(files: [
            "tutorial": Self.chapter("tutorial", puzzles: ["t1", "t2"]),
            "siamese": Self.chapter("siamese", puzzles: ["s1", "s2"]),
        ])
    }

    @Test func flattensChaptersInPlayOrder() throws {
        let catalog = try sampleCatalog()
        #expect(catalog.orderedPuzzles.map(\.id) == ["t1", "t2", "s1", "s2"])
        #expect(catalog.chapters.last?.puzzles.isEmpty == true) // dosyası henüz yok
        #expect(catalog.puzzle(after: "t2")?.id == "s1")
        #expect(catalog.chapter(containing: "s2")?.id == "siamese")
    }

    @Test func tutorialUsesRelaxedRules() throws {
        let catalog = try sampleCatalog()
        #expect(catalog.rules(for: catalog.orderedPuzzles[0]) == .relaxed)
        #expect(catalog.rules(for: catalog.orderedPuzzles[2]) == .classic)
    }

    @Test func rejectsDuplicateIDsAndMismatchedChapters() {
        #expect(throws: CatalogError.duplicatePuzzleID("t1")) {
            try load(files: ["tutorial": Self.chapter("tutorial", puzzles: ["t1", "t1"])])
        }
        #expect(throws: CatalogError.chapterMismatch(expected: "siamese", found: "persian")) {
            try load(files: ["siamese": Self.chapter("persian", puzzles: ["p1"])])
        }
    }

    @Test func unlocksSequentially() throws {
        let catalog = try sampleCatalog()
        var progression = Progression(catalog: catalog, completedIDs: [])
        #expect(progression.isUnlocked("t1"))
        #expect(!progression.isUnlocked("t2"))
        #expect(progression.nextPlayable?.id == "t1")

        progression = Progression(catalog: catalog, completedIDs: ["t1", "t2"])
        #expect(progression.isUnlocked("s1"))
        #expect(!progression.isUnlocked("s2"))
        #expect(progression.isUnlocked(catalog.chapters[1]))
        #expect(progression.completedCount(in: catalog.chapters[0]) == 2)
        #expect(progression.nextPlayable?.id == "s1")
    }
}
