import NonogramKit
import SwiftData
import XCTest
@testable import PurrfectNonogram

@MainActor
final class ProgressStoreTests: XCTestCase {
    let puzzle = Puzzle(id: "plus", pattern: [".#.", "###", ".#."])

    func completion(_ id: String = "plus", elapsed: TimeInterval, mistakes: Int = 0) -> PuzzleCompletion {
        PuzzleCompletion(puzzleID: id, completedAt: Date(timeIntervalSinceReferenceDate: 100), elapsed: elapsed, mistakes: mistakes)
    }

    func testRecordsCompletionAndBestTime() throws {
        let store = ProgressStore.inMemory()

        let first = store.recordCompletion(completion(elapsed: 90, mistakes: 2))
        XCTAssertNil(first.previousBest)
        XCTAssertFalse(first.isNewBest)
        XCTAssertEqual(store.completedIDs, ["plus"])

        let faster = store.recordCompletion(completion(elapsed: 60, mistakes: 0))
        XCTAssertEqual(faster.previousBest, 90)
        XCTAssertTrue(faster.isNewBest)

        let slower = store.recordCompletion(completion(elapsed: 120, mistakes: 1))
        XCTAssertFalse(slower.isNewBest)

        let record = try XCTUnwrap(store.record(for: "plus"))
        XCTAssertEqual(record.bestTime, 60)
        XCTAssertEqual(record.fewestMistakes, 0)
        XCTAssertEqual(record.timesCompleted, 3)
        XCTAssertEqual(record.firstCompletedAt, Date(timeIntervalSinceReferenceDate: 100))
    }

    func testSavesAndRestoresGame() {
        let store = ProgressStore.inMemory()
        var game = NonogramGame(puzzle: puzzle, rules: .classic)
        game.mark(.filled, at: GridPosition(row: 1, column: 0))
        game.advanceTime(by: 30)

        store.saveGame(game.snapshot)
        XCTAssertTrue(store.hasSavedGame(for: "plus"))
        XCTAssertEqual(store.savedGame(for: "plus"), game.snapshot)
        // Yarım oyun, bulmacayı tamamlanmış saymaz
        XCTAssertTrue(store.completedIDs.isEmpty)

        store.clearSavedGame(for: "plus")
        XCTAssertNil(store.savedGame(for: "plus"))
    }

    func testCompletionClearsSavedGame() {
        let store = ProgressStore.inMemory()
        store.saveGame(NonogramGame(puzzle: puzzle, rules: .classic).snapshot)
        store.recordCompletion(completion(elapsed: 10))
        XCTAssertFalse(store.hasSavedGame(for: "plus"))
    }

    func testStatsSummarizeSolvedPuzzles() {
        let store = ProgressStore.inMemory()
        store.recordCompletion(completion("a", elapsed: 30, mistakes: 0))
        store.recordCompletion(completion("b", elapsed: 90, mistakes: 1))
        store.saveGame(NonogramGame(puzzle: puzzle, rules: .classic).snapshot) // çözülmemiş

        let stats = store.stats
        XCTAssertEqual(stats.solvedCount, 2)
        XCTAssertEqual(stats.perfectCount, 1)
        XCTAssertEqual(stats.totalSolveTime, 120)
        XCTAssertEqual(stats.averageSolveTime, 60)
    }

    func testPersistsAcrossStoreInstances() throws {
        let container = try ModelContainer(
            for: PuzzleRecord.self,
            configurations: ModelConfiguration(isStoredInMemoryOnly: true)
        )
        ProgressStore(container: container).recordCompletion(completion(elapsed: 42))
        let reopened = ProgressStore(container: container)
        XCTAssertEqual(reopened.record(for: "plus")?.bestTime, 42)
    }

    func testMigratesLegacyUserDefaultsProgress() throws {
        let defaults = try XCTUnwrap(UserDefaults(suiteName: "ProgressStoreTests-\(UUID().uuidString)"))
        defaults.set(["t1", "t2"], forKey: ProgressStore.legacyCompletedKey)
        let container = try ModelContainer(
            for: PuzzleRecord.self,
            configurations: ModelConfiguration(isStoredInMemoryOnly: true)
        )

        let store = ProgressStore(container: container, legacyDefaults: defaults)
        XCTAssertEqual(store.completedIDs, ["t1", "t2"])
        XCTAssertNil(defaults.stringArray(forKey: ProgressStore.legacyCompletedKey))
    }

    func testResetDeletesEverything() {
        let store = ProgressStore.inMemory()
        store.recordCompletion(completion(elapsed: 10))
        store.resetAll()
        XCTAssertTrue(store.completedIDs.isEmpty)
        XCTAssertNil(store.record(for: "plus"))
        XCTAssertEqual(store.stats, PlayerStats())
    }
}
