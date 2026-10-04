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

    /// Telefonda yakınlaştırmasız rahat oynanması için en büyük tahta 15x15.
    func testBoardsGrowUpTo15() {
        let sides = catalog.orderedPuzzles.map { max($0.rows, $0.columns) }
        XCTAssertEqual(sides.max(), 15)
        XCTAssertLessThanOrEqual(sides.first ?? 0, 5)
    }

    func testEveryBreedHasPortraitAndCard() {
        let breeds = catalog.chapters.filter { $0.kind == .breed }
        for breed in breeds {
            XCTAssertNotNil(breed.portrait, "\(breed.id) portresi yok")
            XCTAssertNotNil(breed.card, "\(breed.id) kartı yok")
            if let card = breed.card {
                XCTAssertNotNil(card.fact.translations["tr"], "\(breed.id) kart bilgisi Türkçe değil")
                for value in [card.stats.energy, card.stats.affection, card.stats.playfulness, card.stats.grooming] {
                    XCTAssertTrue((1...5).contains(value), "\(breed.id) puanı 1-5 dışında")
                }
            }
        }
        XCTAssertEqual(breeds.compactMap(\.card?.number), Array(1...breeds.count), "Kart numaraları sıralı olmalı")
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
