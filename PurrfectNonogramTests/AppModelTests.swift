import NonogramKit
import XCTest
@testable import PurrfectNonogram

@MainActor
final class AppModelTests: XCTestCase {
    func makeModel(defaults: UserDefaults? = nil) throws -> (AppModel, UserDefaults) {
        let defaults = defaults ?? UserDefaults(suiteName: "AppModelTests-\(UUID().uuidString)")!
        let catalog = try LevelCatalog(chapters: [
            Chapter(id: "tutorial", kind: .tutorial, title: ["en": "School"], expectedPuzzleCount: 2,
                    puzzles: [Puzzle(id: "t1", pattern: ["#"]), Puzzle(id: "t2", pattern: ["#"])]),
            Chapter(id: "siamese", kind: .breed, title: ["en": "Siamese"], expectedPuzzleCount: 30,
                    puzzles: [Puzzle(id: "s1", pattern: ["#"])]),
        ])
        return (AppModel(catalog: catalog, defaults: defaults), defaults)
    }

    func completion(_ id: String) -> PuzzleCompletion {
        PuzzleCompletion(puzzleID: id, completedAt: Date(), elapsed: 10, mistakes: 0)
    }

    func testSummarizesProgress() throws {
        let (model, _) = try makeModel()
        XCTAssertEqual(model.plannedPuzzleCount, 32)
        XCTAssertEqual(model.completedCount, 0)
        XCTAssertEqual(model.progression.nextPlayable?.id, "t1")

        model.record(completion("t1"))
        XCTAssertEqual(model.completedCount, 1)
        XCTAssertEqual(model.progression.nextPlayable?.id, "t2")
    }

    func testPersistsCompletions() throws {
        let (model, defaults) = try makeModel()
        model.record(completion("t1"))
        let (reloaded, _) = try makeModel(defaults: defaults)
        XCTAssertTrue(reloaded.progression.isCompleted("t1"))
    }

    func testNumbersPuzzlesWithinChapter() throws {
        let (model, _) = try makeModel()
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
