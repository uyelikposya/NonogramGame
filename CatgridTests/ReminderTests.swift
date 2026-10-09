import XCTest
@testable import Catgrid

final class ReminderTests: XCTestCase {
    private var calendar: Calendar {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(identifier: "Europe/Istanbul")!
        return calendar
    }

    private func date(_ day: Int, _ hour: Int, _ minute: Int = 0) -> Date {
        calendar.date(from: DateComponents(year: 2026, month: 10, day: day, hour: hour, minute: minute))!
    }

    func testStartsTodayWhenNotPlayedAndTimeAhead() {
        let dates = ReminderSchedule.dates(now: date(9, 10), hour: 19, minute: 30, playedToday: false, days: 3, calendar: calendar)
        XCTAssertEqual(dates, [date(9, 19, 30), date(10, 19, 30), date(11, 19, 30)])
    }

    /// Bugün oynadıysa ya da saat geçtiyse ilk hatırlatma yarın.
    func testSkipsTodayWhenPlayedOrTimePassed() {
        let played = ReminderSchedule.dates(now: date(9, 10), hour: 19, minute: 0, playedToday: true, days: 2, calendar: calendar)
        XCTAssertEqual(played, [date(10, 19), date(11, 19)])
        let late = ReminderSchedule.dates(now: date(9, 20), hour: 19, minute: 0, playedToday: false, days: 1, calendar: calendar)
        XCTAssertEqual(late, [date(10, 19)])
    }

    @MainActor
    func testOffersOnceAfterAFewPuzzles() throws {
        let defaults = try XCTUnwrap(UserDefaults(suiteName: "ReminderTests"))
        defaults.removePersistentDomain(forName: "ReminderTests")
        let reminders = ReminderManager(defaults: defaults, center: nil)
        XCTAssertFalse(reminders.shouldOffer(solvedCount: 2))
        XCTAssertTrue(reminders.shouldOffer(solvedCount: 3))
        reminders.markAsked()
        XCTAssertFalse(ReminderManager(defaults: defaults, center: nil).shouldOffer(solvedCount: 10))
        XCTAssertEqual(reminders.hour, 19)
    }

    func testRatingAsksOncePerThreshold() {
        XCTAssertNil(RatingPolicy.threshold(solved: 9, lastPrompted: 0))
        XCTAssertEqual(RatingPolicy.threshold(solved: 10, lastPrompted: 0), 10)
        XCTAssertNil(RatingPolicy.threshold(solved: 25, lastPrompted: 10))
        XCTAssertEqual(RatingPolicy.threshold(solved: 45, lastPrompted: 10), 40)
    }
}
