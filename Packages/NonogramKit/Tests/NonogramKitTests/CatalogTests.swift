import XCTest
@testable import NonogramKit

final class PuzzleDecodingTests: XCTestCase {
    func decode(_ json: String) throws -> Puzzle {
        try JSONDecoder().decode(Puzzle.self, from: Data(json.utf8))
    }

    func testDecodesArtworkAndClues() throws {
        let puzzle = try decode("""
        {
          "id": "paw", "title": { "en": "Paw", "tr": "Pati" },
          "palette": { "a": "#4A3B35", "b": "f2d7c9" },
          "pixels": ["a.a", ".b.", "bbb"]
        }
        """)
        XCTAssertEqual(puzzle.rows, 3)
        XCTAssertEqual(puzzle.columns, 3)
        XCTAssertEqual(puzzle.rowClues, [[1, 1], [1], [3]])
        XCTAssertEqual(puzzle.columnClues, [[1, 1], [2], [1, 1]])
        XCTAssertEqual(puzzle.artwork[0, 0], RGBColor(red: 0x4A, green: 0x3B, blue: 0x35))
        XCTAssertNil(puzzle.artwork[0, 1])
        XCTAssertEqual(puzzle.title.resolved(preferredLanguages: ["tr-TR"]), "Pati")
        XCTAssertNil(puzzle.rulesOverride)
    }

    func testDecodesRulesOverride() throws {
        let puzzle = try decode("""
        { "id": "boss", "title": { "en": "Boss" }, "palette": { "a": "#000000" },
          "pixels": ["a"], "rules": { "mistakeLimit": null, "timeLimitSeconds": 120 } }
        """)
        XCTAssertEqual(puzzle.rulesOverride, GameRules(mistakeLimit: nil, timeLimit: 120))
    }

    func testRejectsInvalidContent() {
        let invalid = [
            ##"{ "id": "x", "title": {}, "palette": { "a": "#000000" }, "pixels": ["ab"] }"##,
            ##"{ "id": "x", "title": {}, "palette": { "a": "#000000" }, "pixels": ["aa", "a"] }"##,
            ##"{ "id": "x", "title": {}, "palette": { "a": "red" }, "pixels": ["a"] }"##,
            ##"{ "id": "x", "title": {}, "palette": { "a": "#000000" }, "pixels": ["..."] }"##,
        ]
        for json in invalid {
            XCTAssertThrowsError(try decode(json), json) { error in
                XCTAssertTrue(error is DecodingError, json)
            }
        }
    }
}

final class CatalogTests: XCTestCase {
    static let catalogJSON = """
    {
      "schemaVersion": 1,
      "chapters": [
        { "id": "tutorial", "kind": "tutorial", "title": { "en": "School" }, "file": "tutorial", "expectedPuzzleCount": 2 },
        { "id": "siamese", "kind": "breed", "title": { "en": "Siamese" }, "file": "siamese", "expectedPuzzleCount": 2,
          "portrait": { "palette": { "a": "#4A3B35" }, "pixels": ["a.a", "aaa"] },
          "card": { "number": 1, "rarity": "common", "origin": { "en": "Thailand" }, "lifespan": "15–20",
                    "coat": { "en": "Short" }, "fact": { "en": "Talkative." }, "about": { "en": "An old breed." },
                    "stats": { "energy": 5, "affection": 5, "playfulness": 5, "grooming": 1 } } },
        { "id": "persian", "kind": "breed", "title": { "en": "Persian" }, "file": "persian" }
      ]
    }
    """

    static func chapter(_ id: String, puzzles: [String]) -> String {
        let items = puzzles.map {
            ##"{ "id": "\##($0)", "title": { "en": "P" }, "palette": { "a": "#000000" }, "pixels": ["a."] }"##
        }
        return ##"{ "schemaVersion": 1, "chapterID": "\##(id)", "puzzles": [\##(items.joined(separator: ","))] }"##
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

    func testFlattensChaptersInPlayOrder() throws {
        let catalog = try sampleCatalog()
        XCTAssertEqual(catalog.orderedPuzzles.map(\.id), ["t1", "t2", "s1", "s2"])
        XCTAssertEqual(catalog.chapters.last?.puzzles.isEmpty, true) // dosyası henüz yok
        XCTAssertEqual(catalog.chapters.last?.expectedPuzzleCount, 0) // sayı belirtilmemiş
        XCTAssertEqual(catalog.puzzle(after: "t2")?.id, "s1")
        XCTAssertEqual(catalog.chapter(containing: "s2")?.id, "siamese")
    }

    func testDecodesBreedPortraitAndCard() throws {
        let catalog = try sampleCatalog()
        let siamese = catalog.chapters[1]
        XCTAssertEqual(siamese.portrait?.rows, 2)
        XCTAssertEqual(siamese.portrait?.columns, 3)
        XCTAssertNil(siamese.portrait?[0, 1])
        XCTAssertEqual(siamese.card?.number, 1)
        XCTAssertEqual(siamese.card?.rarity, .common)
        XCTAssertEqual(siamese.card?.stats.energy, 5)
        XCTAssertEqual(siamese.card?.lifespan, "15–20")
        XCTAssertEqual(siamese.card?.about?.translations["en"], "An old breed.")
        XCTAssertNil(catalog.chapters[0].card) // eğitimin kartı yok
    }

    func testTutorialUsesRelaxedRules() throws {
        let catalog = try sampleCatalog()
        XCTAssertEqual(catalog.rules(for: catalog.orderedPuzzles[0]), .relaxed)
        XCTAssertEqual(catalog.rules(for: catalog.orderedPuzzles[2]), .classic)
    }

    func testRejectsDuplicateIDsAndMismatchedChapters() {
        XCTAssertThrowsError(try load(files: ["tutorial": Self.chapter("tutorial", puzzles: ["t1", "t1"])])) {
            XCTAssertEqual($0 as? CatalogError, .duplicatePuzzleID("t1"))
        }
        XCTAssertThrowsError(try load(files: ["siamese": Self.chapter("persian", puzzles: ["p1"])])) {
            XCTAssertEqual($0 as? CatalogError, .chapterMismatch(expected: "siamese", found: "persian"))
        }
    }

    func testUnlocksSequentially() throws {
        let catalog = try sampleCatalog()
        var progression = Progression(catalog: catalog, completedIDs: [])
        XCTAssertTrue(progression.isUnlocked("t1"))
        XCTAssertFalse(progression.isUnlocked("t2"))
        XCTAssertEqual(progression.nextPlayable?.id, "t1")

        progression = Progression(catalog: catalog, completedIDs: ["t1", "t2"])
        XCTAssertTrue(progression.isUnlocked("s1"))
        XCTAssertFalse(progression.isUnlocked("s2"))
        XCTAssertTrue(progression.isUnlocked(catalog.chapters[1]))
        XCTAssertEqual(progression.completedCount(in: catalog.chapters[0]), 2)
        XCTAssertEqual(progression.nextPlayable?.id, "s1")
    }
}
