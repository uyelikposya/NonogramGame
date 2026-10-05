import NonogramKit
import XCTest
@testable import Catgrid

@MainActor
final class AppModelTests: XCTestCase {
    func makeModel() throws -> AppModel {
        let catalog = try LevelCatalog(chapters: [
            Chapter(id: "tutorial", kind: .tutorial, title: ["en": "School"], expectedPuzzleCount: 2,
                    puzzles: [Puzzle(id: "t1", pattern: ["#"]), Puzzle(id: "t2", pattern: ["#"])]),
            Chapter(id: "siamese", kind: .breed, title: ["en": "Siamese"], expectedPuzzleCount: 30,
                    puzzles: [Puzzle(id: "s1", pattern: ["#"])],
                    card: BreedCard(number: 1, rarity: .common, origin: ["en": "Thailand"], lifespan: "15",
                                    coat: ["en": "Short"], stats: .init(energy: 1, affection: 1, playfulness: 1, grooming: 1),
                                    fact: ["en": "Talkative"]),
                    premiumPuzzles: [Puzzle(id: "sp1", pattern: ["#"]), Puzzle(id: "sp2", pattern: ["#"])]),
        ])
        return AppModel(catalog: catalog, progress: .inMemory())
    }

    func completion(_ id: String) -> PuzzleCompletion {
        PuzzleCompletion(puzzleID: id, completedAt: Date(), elapsed: 10, mistakes: 0)
    }

    func testSummarizesProgress() throws {
        let model = try makeModel()
        XCTAssertEqual(model.completedCount, 0)
        XCTAssertEqual(model.progression.nextPlayable?.id, "t1")

        model.record(completion("t1"))
        XCTAssertEqual(model.completedCount, 1)
        XCTAssertEqual(model.progression.nextPlayable?.id, "t2")
    }

    func testResumesMostRecentSavedGame() throws {
        let model = try makeModel()
        model.record(completion("t1"))
        XCTAssertEqual(model.resumablePuzzle?.id, "t2")

        // t1 tekrar oynanıp yarım bırakılırsa "Devam Et" ona döner
        let t1 = try XCTUnwrap(model.catalog.puzzle(withID: "t1"))
        var game = NonogramGame(puzzle: t1, rules: GameRules(checksMoves: false))
        game.mark(.crossed, at: GridPosition(row: 0, column: 0))
        model.progress.saveGame(game.snapshot)
        XCTAssertEqual(model.resumablePuzzle?.id, "t1")
    }

    func testCollectsBreedWhenAllPuzzlesSolved() throws {
        let model = try makeModel()
        XCTAssertEqual(model.breeds.map(\.id), ["siamese"])
        XCTAssertTrue(model.collectedBreeds.isEmpty)

        model.record(completion("t1"))
        model.record(completion("t2"))
        XCTAssertTrue(model.collectedBreeds.isEmpty) // eğitim koleksiyona sayılmaz

        model.record(completion("s1"))
        XCTAssertEqual(model.collectedBreeds.map(\.id), ["siamese"])
        XCTAssertFalse(model.hasUnmetBreeds)
    }

    func testGoldenCardNeedsEveryPremiumPuzzle() throws {
        let model = try makeModel()
        let siamese = try XCTUnwrap(model.chapter(withID: "siamese"))
        model.record(completion("sp1"))
        XCTAssertFalse(model.isGoldenCollected(siamese))
        XCTAssertEqual(model.completedCount, 0, "Premium bulmacalar normal ilerlemeye sayılmaz")

        model.record(completion("sp2"))
        XCTAssertTrue(model.isGoldenCollected(siamese))
        // Normal kart henüz yokken de Altın Kart koleksiyonda görünür
        XCTAssertEqual(model.collectedCards.map(\.id), ["siamese#golden"])

        model.record(completion("t1"))
        model.record(completion("t2"))
        model.record(completion("s1"))
        XCTAssertEqual(model.collectedCards.map(\.id), ["siamese", "siamese#golden"])
        XCTAssertEqual(model.goldenBreeds.map(\.id), ["siamese"])
    }

    func testNumbersPremiumPuzzlesSeparately() throws {
        let model = try makeModel()
        let sp2 = try XCTUnwrap(model.catalog.puzzle(withID: "sp2"))
        let sp1 = try XCTUnwrap(model.catalog.puzzle(withID: "sp1"))
        XCTAssertEqual(model.number(of: sp2), 2)
        XCTAssertEqual(model.nextPuzzle(after: sp1)?.id, "sp2")
        XCTAssertNil(model.nextPuzzle(after: sp2))
    }

    func testResetClearsProgress() throws {
        let model = try makeModel()
        model.record(completion("t1"))
        model.resetProgress()
        XCTAssertEqual(model.completedCount, 0)
        XCTAssertEqual(model.progression.nextPlayable?.id, "t1")
    }

    func testNumbersPuzzlesWithinChapter() throws {
        let model = try makeModel()
        let s1 = try XCTUnwrap(model.catalog.puzzle(withID: "s1"))
        let t2 = try XCTUnwrap(model.catalog.puzzle(withID: "t2"))
        XCTAssertEqual(model.number(of: s1), 1)
        XCTAssertEqual(model.number(of: t2), 2)
        XCTAssertEqual(model.nextPuzzle(after: t2)?.id, "s1")
        XCTAssertEqual(model.chapter(withID: "siamese")?.puzzles.count, 1)
    }
}

@MainActor
final class RouterTests: XCTestCase {
    func testReplaceTopSwapsOnlyLastScreen() {
        let router = Router()
        router.push(.chapters)
        router.push(.game(puzzleID: "a"))
        router.replaceTop(with: .game(puzzleID: "b"))
        XCTAssertEqual(router.path, [.chapters, .game(puzzleID: "b")])
        router.pop()
        XCTAssertEqual(router.path, [.chapters])
    }
}
