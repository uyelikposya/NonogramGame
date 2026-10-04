import NonogramKit
import XCTest
@testable import PurrfectNonogram

/// Uygulamaya paketlenen gerçek bulmaca içeriğini doğrular.
/// Aynı kontroller Xcode'suz ortamda `Tools/validate_puzzles.py` ile de çalışır.
final class ContentValidationTests: XCTestCase {
    private var catalog: LevelCatalog!

    override func setUpWithError() throws {
        catalog = try CatalogLoader.load(from: .main)
    }

    func testStartsWithTutorialFollowedByFifteenBreeds() {
        XCTAssertEqual(catalog.chapters.first?.kind, .tutorial)
        XCTAssertEqual(catalog.chapters.filter { $0.kind == .breed }.count, 15)
        XCTAssertEqual(catalog.chapters.map(\.expectedPuzzleCount).reduce(0, +), 460)
    }

    func testEveryPuzzleHasUniqueLogicalSolution() {
        for puzzle in catalog.orderedPuzzles {
            XCTAssertTrue(PuzzleSolver.isLogicallySolvable(puzzle), "\(puzzle.id) tahmin gerektiriyor")
        }
    }

    func testEveryTitleIsTranslated() {
        for puzzle in catalog.orderedPuzzles {
            XCTAssertNotNil(puzzle.title.translations["en"], "\(puzzle.id) İngilizce başlık eksik")
            XCTAssertNotNil(puzzle.title.translations["tr"], "\(puzzle.id) Türkçe başlık eksik")
        }
    }

    func testTutorialCoversEveryLesson() throws {
        let tutorial = try XCTUnwrap(catalog.chapters.first { $0.kind == .tutorial })
        XCTAssertEqual(Set(tutorial.puzzles.compactMap(\.lesson)), Set(TutorialLesson.allCases))
    }
}
