import XCTest
@testable import NonogramKit

final class StarRatingTests: XCTestCase {
    func testSpeedTargetGrowsWithBoardSize() {
        let expected = [5: 20.0, 6: 24, 7: 28, 8: 33, 9: 39, 10: 45, 11: 52, 12: 60, 15: 60]
        for (size, seconds) in expected {
            XCTAssertEqual(StarRating.speedTarget(rows: size, columns: size), seconds, "\(size)×\(size)")
        }
        XCTAssertEqual(StarRating.speedTarget(rows: 1, columns: 2), 10)
        XCTAssertEqual(StarRating.speedTarget(rows: 20, columns: 10), 60)
    }

    func testStarsFromMistakesAndSpeed() {
        XCTAssertEqual(StarRating.stars(mistakes: 0, elapsed: 20, rows: 5, columns: 5), 4)
        XCTAssertEqual(StarRating.stars(mistakes: 0, elapsed: 21, rows: 5, columns: 5), 3)
        XCTAssertEqual(StarRating.stars(mistakes: 1, elapsed: 10, rows: 5, columns: 5), 3)
        XCTAssertEqual(StarRating.stars(mistakes: 2, elapsed: 90, rows: 5, columns: 5), 1)
        XCTAssertEqual(StarRating.stars(mistakes: 5, elapsed: 90, rows: 5, columns: 5), 1)
    }
}
