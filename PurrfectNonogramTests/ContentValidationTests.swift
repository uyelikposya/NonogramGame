import Foundation
import NonogramKit
import Testing
@testable import PurrfectNonogram

/// Uygulamaya paketlenen gerçek bulmaca içeriğini doğrular.
/// Aynı kontroller Xcode'suz ortamda `Tools/validate_puzzles.py` ile de çalışır.
struct ContentValidationTests {
    let catalog: LevelCatalog

    init() throws {
        catalog = try CatalogLoader.load(from: .main)
    }

    @Test func startsWithTutorialFollowedByFifteenBreeds() {
        #expect(catalog.chapters.first?.kind == .tutorial)
        #expect(catalog.chapters.filter { $0.kind == .breed }.count == 15)
        #expect(catalog.chapters.map(\.expectedPuzzleCount).reduce(0, +) == 460)
    }

    @Test func everyPuzzleHasUniqueLogicalSolution() {
        for puzzle in catalog.orderedPuzzles {
            #expect(PuzzleSolver.isLogicallySolvable(puzzle), "\(puzzle.id) tahmin gerektiriyor")
        }
    }

    @Test func everyTitleIsTranslated() {
        for puzzle in catalog.orderedPuzzles {
            #expect(puzzle.title.translations["en"] != nil, "\(puzzle.id) İngilizce başlık eksik")
            #expect(puzzle.title.translations["tr"] != nil, "\(puzzle.id) Türkçe başlık eksik")
        }
    }

    @Test func tutorialCoversEveryLesson() throws {
        let tutorial = try #require(catalog.chapters.first { $0.kind == .tutorial })
        #expect(Set(tutorial.puzzles.compactMap(\.lesson)) == Set(TutorialLesson.allCases))
    }
}
