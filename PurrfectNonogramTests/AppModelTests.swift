import NonogramKit
import XCTest
@testable import PurrfectNonogram

@MainActor
final class AppModelTests: XCTestCase {
    func makeModel() throws -> AppModel {
        let catalog = try LevelCatalog(chapters: [
            Chapter(id: "tutorial", kind: .tutorial, title: ["en": "School"], expectedPuzzleCount: 2,
                    puzzles: [Puzzle(id: "t1", pattern: ["#"]), Puzzle(id: "t2", pattern: ["#"])]),
            Chapter(id: "siamese", kind: .breed, title: ["en": "Siamese"], expectedPuzzleCount: 30,
                    puzzles: [Puzzle(id: "s1", pattern: ["#"])]),
        ])
        return AppModel(catalog: catalog, progress: .inMemory())
    }

    func completion(_ id: String) -> PuzzleCompletion {
        PuzzleCompletion(puzzleID: id, completedAt: Date(), elapsed: 10, mistakes: 0)
    }

    func testSummarizesProgress() throws {
        let model = try makeModel()
        XCTAssertEqual(model.plannedPuzzleCount, 32)
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
