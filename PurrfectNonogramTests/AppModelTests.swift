import Foundation
import NonogramKit
import Testing
@testable import PurrfectNonogram

@MainActor
struct AppModelTests {
    func makeModel(defaults: UserDefaults? = nil) throws -> (AppModel, UserDefaults) {
        let name = "AppModelTests-\(UUID().uuidString)"
        let defaults = defaults ?? UserDefaults(suiteName: name)!
        let catalog = try LevelCatalog(chapters: [
            Chapter(id: "tutorial", kind: .tutorial, title: ["en": "School"], subtitle: nil, accentColor: nil,
                    expectedPuzzleCount: 2,
                    puzzles: [Puzzle(id: "t1", pattern: ["#"]), Puzzle(id: "t2", pattern: ["#"])]),
            Chapter(id: "siamese", kind: .breed, title: ["en": "Siamese"], subtitle: nil, accentColor: nil,
                    expectedPuzzleCount: 30,
                    puzzles: [Puzzle(id: "s1", pattern: ["#"])]),
        ])
        return (AppModel(catalog: catalog, defaults: defaults), defaults)
    }

    @Test func summarizesProgress() throws {
        let (model, _) = try makeModel()
        #expect(model.plannedPuzzleCount == 32)
        #expect(model.completedCount == 0)
        #expect(model.progression.nextPlayable?.id == "t1")

        model.record(PuzzleCompletion(puzzleID: "t1", completedAt: .now, elapsed: 10, mistakes: 0))
        #expect(model.completedCount == 1)
        #expect(model.progression.nextPlayable?.id == "t2")
    }

    @Test func persistsCompletions() throws {
        let (model, defaults) = try makeModel()
        model.record(PuzzleCompletion(puzzleID: "t1", completedAt: .now, elapsed: 10, mistakes: 0))
        let (reloaded, _) = try makeModel(defaults: defaults)
        #expect(reloaded.progression.isCompleted("t1"))
    }

    @Test func numbersPuzzlesWithinChapter() throws {
        let (model, _) = try makeModel()
        let s1 = try #require(model.catalog.puzzle(withID: "s1"))
        let t2 = try #require(model.catalog.puzzle(withID: "t2"))
        #expect(model.number(of: s1) == 1)
        #expect(model.number(of: t2) == 2)
        #expect(model.nextPuzzle(after: t2)?.id == "s1")
        #expect(model.chapter(withID: "siamese")?.puzzles.count == 1)
    }
}

@MainActor
struct RouterTests {
    @Test func replaceTopSwapsOnlyLastScreen() {
        let router = Router()
        router.push(.chapters)
        router.push(.game(puzzleID: "a"))
        router.replaceTop(with: .game(puzzleID: "b"))
        #expect(router.path == [.chapters, .game(puzzleID: "b")])
        router.pop()
        #expect(router.path == [.chapters])
    }
}
