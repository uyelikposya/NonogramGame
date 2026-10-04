import NonogramKit
import XCTest
@testable import Catgrid

/// Uygulamaya paketlenen gerçek bulmaca içeriğini doğrular.
/// Aynı kontroller Xcode'suz ortamda `Tools/validate_puzzles.py` ile de çalışır.
final class ContentValidationTests: XCTestCase {
    private var catalog: LevelCatalog!

    override func setUpWithError() throws {
        catalog = try CatalogLoader.load(from: .main)
    }

    func testStartsWithTutorialFollowedByBreeds() {
        XCTAssertEqual(catalog.chapters.first?.kind, .tutorial)
        XCTAssertEqual(catalog.chapters.first?.puzzles.count, 10)
        let breeds = catalog.chapters.filter { $0.kind == .breed }
        XCTAssertGreaterThanOrEqual(breeds.count, 15)
        for breed in breeds {
            XCTAssertGreaterThanOrEqual(breed.puzzles.count, 15, "\(breed.id) en az 15 bulmaca içermeli")
            XCTAssertNotNil(breed.subtitle, "\(breed.id) tür bilgisi eksik")
        }
    }

    func testBoardsGrowUpTo20() {
        let sides = catalog.orderedPuzzles.map { max($0.rows, $0.columns) }
        XCTAssertEqual(sides.max(), 20)
        XCTAssertLessThanOrEqual(sides.first ?? 0, 5)
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
