import XCTest
@testable import NonogramKit

final class CatGameTests: XCTestCase {
    /// Eğitim bölümü: sol üstteki tek kareli renk hemen kedi.
    let tutorial = CatLevel(
        id: "cat-001",
        regions: ["abbcc", "dbbcc", "ddccc", "dddee", "eeeee"],
        solution: [0, 2, 4, 1, 3],
        breeds: ["siamese", "persian", "manx", "bengal", "sphynx"]
    )

    private func position(_ row: Int, _ column: Int) -> GridPosition {
        GridPosition(row: row, column: column)
    }

    func testLevelParsesRegions() {
        XCTAssertEqual(tutorial.size, 5)
        XCTAssertEqual(tutorial.region(at: position(0, 0)), 0)
        XCTAssertEqual(tutorial.region(at: position(4, 4)), 4)
        XCTAssertEqual(tutorial.catPosition(ofRegion: 2), position(2, 4))
        XCTAssertEqual(tutorial.cells(ofRegion: 0), [position(0, 0)])
    }

    func testTapCyclesCrossThenCat() {
        var game = CatGame(level: tutorial)
        XCTAssertEqual(game.tap(at: position(0, 0)), .crossed)
        XCTAssertEqual(game[position(0, 0)], .cross)
        guard case .found(let find) = game.tap(at: position(0, 0)) else {
            return XCTFail("kedi bulunmalıydı")
        }
        XCTAssertEqual(find.region, 0)
        XCTAssertTrue(find.perfectlyMarked, "tek kareli renkte başka kare yok")
        XCTAssertEqual(game[position(0, 0)], .cat)
        // Satır, sütun ve komşular X'lendi
        XCTAssertEqual(game[position(0, 4)], .cross)
        XCTAssertEqual(game[position(4, 0)], .cross)
        XCTAssertEqual(game[position(1, 1)], .cross)
        XCTAssertEqual(game[position(2, 2)], .blank)
        XCTAssertEqual(game.tap(at: position(0, 0)), .ignored, "kedi kilitli")
    }

    func testWrongCatCostsALifeAndLocks() {
        var game = CatGame(level: tutorial)
        game.tap(at: position(2, 2))
        XCTAssertEqual(game.tap(at: position(2, 2)), .mistake(position(2, 2)))
        XCTAssertEqual(game[position(2, 2)], .wrong)
        XCTAssertEqual(game.remainingLives, 2)
        XCTAssertEqual(game.tap(at: position(2, 2)), .ignored)
        XCTAssertEqual(game.placeCat(at: position(3, 3)), .mistake(position(3, 3)))
        XCTAssertEqual(game.placeCat(at: position(4, 4)), .failed(position(4, 4)))
        XCTAssertEqual(game.status, .lost)
        game.revive()
        XCTAssertEqual(game.status, .playing)
        XCTAssertEqual(game.remainingLives, 1)
    }

    func testPaintCrossesAndClears() {
        var game = CatGame(level: tutorial)
        XCTAssertEqual(game.paint(cross: true, at: position(1, 1)), .crossed)
        XCTAssertEqual(game.paint(cross: true, at: position(1, 1)), .ignored)
        XCTAssertEqual(game.paint(cross: false, at: position(1, 1)), .cleared)
        XCTAssertEqual(game[position(1, 1)], .blank)
    }

    func testFirstHintIsTheSingleCellColor() {
        let game = CatGame(level: tutorial)
        let hint = game.hint()
        XCTAssertEqual(hint?.kind, .onlySpot(CatGroup(axis: .region, index: 0)))
        XCTAssertEqual(hint?.cells, [position(0, 0)])
    }

    func testHintsSolveTutorialWithoutMistakes() {
        var game = CatGame(level: tutorial)
        var steps = 0
        while game.status == .playing, let hint = game.hint(), steps < 100 {
            game.apply(hint)
            steps += 1
        }
        XCTAssertEqual(game.status, .won)
        XCTAssertEqual(game.mistakes, 0)
    }

    func testRevealCatFindsACat() {
        var game = CatGame(level: tutorial)
        guard case .found(let find) = game.revealCat() else {
            return XCTFail("kedi gösterilmeliydi")
        }
        XCTAssertTrue(find.revealed)
        XCTAssertEqual(find.region, 0, "en kısıtlı renk önce")
    }

    func testSolvingAllCatsWins() {
        var game = CatGame(level: tutorial)
        var last: CatMove = .ignored
        for row in 0..<5 {
            last = game.placeCat(at: position(row, tutorial.solution[row]))
        }
        guard case .solved = last else { return XCTFail("bitmeliydi") }
        XCTAssertEqual(game.status, .won)
    }

    func testSnapshotRoundTrip() throws {
        var game = CatGame(level: tutorial)
        game.tap(at: position(3, 3))
        game.placeCat(at: position(0, 0))
        game.elapsed = 12
        let data = try JSONEncoder().encode(game.snapshot)
        let snapshot = try JSONDecoder().decode(CatSnapshot.self, from: data)
        let restored = CatGame(level: tutorial, restoring: snapshot)
        XCTAssertEqual(restored.marks, game.marks)
        XCTAssertEqual(restored.elapsed, 12)
    }

    func testLevelDecodesFromJSON() throws {
        let json = #"{"levels":[{"id":"cat-001","size":5,"regions":["abbcc","dbbcc","ddccc","dddee","eeeee"],"solution":[0,2,4,1,3],"breeds":["a","b","c","d","e"],"difficulty":0}]}"#
        let pack = try JSONDecoder().decode(CatLevelPack.self, from: Data(json.utf8))
        XCTAssertEqual(pack.levels.first?.regionMap, tutorial.regionMap)
        XCTAssertEqual(pack.number(of: tutorial), 1)
    }
}
