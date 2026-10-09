import XCTest
@testable import NonogramKit

final class DailyPuzzlesTests: XCTestCase {
    func testDayKeyRoundTripsThroughPuzzleID() {
        let day = DayKey(year: 2026, month: 3, day: 1)
        XCTAssertEqual(day.puzzleID, "daily-2026-03-01")
        XCTAssertEqual(DayKey(puzzleID: "daily-2026-03-01"), day)
        XCTAssertNil(DayKey(puzzleID: "siamese-001"))
        // Ardışık günler, ay ve artık yıl sınırında da ardışık sayılar
        XCTAssertEqual(DayKey(year: 2028, month: 3, day: 1).dayNumber - DayKey(year: 2028, month: 2, day: 28).dayNumber, 2)
        XCTAssertEqual(DayKey(year: 2027, month: 1, day: 1).dayNumber - DayKey(year: 2026, month: 12, day: 31).dayNumber, 1)
    }

    func testPicksSamePuzzlePerDayWithDayID() throws {
        let daily = DailyPuzzles(pool: [Puzzle(id: "a", pattern: ["#."]), Puzzle(id: "b", pattern: [".#"])])
        let today = DayKey(year: 2026, month: 10, day: 9)
        let tomorrow = DayKey(year: 2026, month: 10, day: 10)
        let first = try XCTUnwrap(daily.puzzle(for: today))
        XCTAssertEqual(first.id, "daily-2026-10-09")
        XCTAssertEqual(daily.puzzle(withID: first.id)?.solution, first.solution)
        XCTAssertNotEqual(daily.puzzle(for: tomorrow)?.solution, first.solution)
        XCTAssertNil(DailyPuzzles.empty.puzzle(for: today))
    }

    func testStreakCountsBackFromTodayOrYesterday() {
        let today = DayKey(year: 2026, month: 10, day: 9)
        let days: Set<DayKey> = [
            DayKey(year: 2026, month: 10, day: 8), DayKey(year: 2026, month: 10, day: 7),
            DayKey(year: 2026, month: 10, day: 5),
        ]
        XCTAssertEqual(DailyPuzzles.streak(solvedDays: days, today: today), 2)
        XCTAssertEqual(DailyPuzzles.streak(solvedDays: days.union([today]), today: today), 3)
        XCTAssertEqual(DailyPuzzles.streak(solvedDays: days, today: DayKey(year: 2026, month: 10, day: 11)), 0)
    }
}
