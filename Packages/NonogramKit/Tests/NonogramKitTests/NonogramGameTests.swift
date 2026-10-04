import XCTest
@testable import NonogramKit

final class NonogramGameTests: XCTestCase {
    /// Satırlar: [1], [3], [1]  —  ".#." / "###" / ".#."
    let plus = Puzzle(id: "plus", pattern: [".#.", "###", ".#."])

    func position(_ row: Int, _ column: Int) -> GridPosition {
        GridPosition(row: row, column: column)
    }

    func fillAll(_ game: inout NonogramGame) {
        for cell in game.puzzle.solution.positions where game.puzzle.solution[cell] {
            game.mark(.filled, at: cell)
        }
    }

    func testCorrectFillsWin() {
        var game = NonogramGame(puzzle: plus, rules: .classic)
        fillAll(&game)
        XCTAssertEqual(game.status, .won)
        XCTAssertEqual(game.mistakes, 0)
        XCTAssertEqual(game.progress, 1)
    }

    func testWrongFillIsMistakeAndLocksCorrection() {
        var game = NonogramGame(puzzle: plus, rules: .classic)
        XCTAssertEqual(game.toggle(at: position(0, 0), with: .fill), .mistake)
        XCTAssertEqual(game.board[position(0, 0)], .crossed)
        XCTAssertEqual(game.remainingMistakes, 2)
        // Kilitli kare değiştirilemez
        XCTAssertEqual(game.toggle(at: position(0, 0), with: .cross), .ignored)
    }

    func testWrongCrossRevealsFilledCell() {
        var game = NonogramGame(puzzle: plus, rules: .classic)
        XCTAssertEqual(game.toggle(at: position(1, 1), with: .cross), .mistake)
        XCTAssertEqual(game.board[position(1, 1)], .filled)
    }

    func testLosesAfterMistakeLimit() {
        var game = NonogramGame(puzzle: plus, rules: .classic)
        game.mark(.filled, at: position(0, 0))
        game.mark(.filled, at: position(0, 2))
        XCTAssertEqual(game.mark(.filled, at: position(2, 0)), .failed(.outOfMistakes))
        XCTAssertEqual(game.status, .lost(.outOfMistakes))
        XCTAssertEqual(game.mark(.filled, at: position(1, 1)), .ignored)

        game.revive()
        XCTAssertEqual(game.status, .playing)
        XCTAssertEqual(game.remainingMistakes, 1)
    }

    func testAutoCrossesCompletedLine() {
        var game = NonogramGame(puzzle: plus, rules: .classic)
        game.mark(.filled, at: position(0, 1))
        XCTAssertEqual(game.board[position(0, 0)], .crossed)
        XCTAssertEqual(game.board[position(0, 2)], .crossed)
        XCTAssertTrue(game.isRowSatisfied(0))
    }

    func testUndoRevertsMoveWithAutoCrosses() {
        var game = NonogramGame(puzzle: plus, rules: .classic)
        game.mark(.filled, at: position(0, 1))
        XCTAssertTrue(game.undo())
        XCTAssertTrue(game.board.storage.allSatisfy { $0 == .blank })
        XCTAssertFalse(game.canUndo)
    }

    func testToggleDoesNotOverwriteOtherMark() {
        var game = NonogramGame(puzzle: plus, rules: GameRules(checksMoves: false))
        game.toggle(at: position(0, 0), with: .cross)
        XCTAssertEqual(game.toggle(at: position(0, 0), with: .fill), .ignored)
        XCTAssertEqual(game.toggle(at: position(0, 0), with: .cross), .changed)
        XCTAssertEqual(game.board[position(0, 0)], .blank)
    }

    func testFreeModeAllowsWrongMarksAndWinsOnClues() {
        var game = NonogramGame(puzzle: plus, rules: GameRules(checksMoves: false, autoCrossCompletedLines: false))
        XCTAssertEqual(game.mark(.filled, at: position(0, 0)), .changed)
        XCTAssertEqual(game.mistakes, 0)
        game.mark(.blank, at: position(0, 0))
        fillAll(&game)
        XCTAssertEqual(game.status, .won)
    }

    func testTimeLimitEndsGame() {
        var game = NonogramGame(puzzle: plus, rules: GameRules(timeLimit: 10))
        game.advanceTime(by: 6)
        XCTAssertEqual(game.remainingTime, 4)
        XCTAssertEqual(game.advanceTime(by: 6), .failed(.outOfTime))
        XCTAssertEqual(game.remainingTime, 0)
    }

    func testSnapshotRestoresProgress() {
        var game = NonogramGame(puzzle: plus, rules: .classic)
        game.mark(.filled, at: position(1, 0))
        game.mark(.filled, at: position(0, 0))
        game.advanceTime(by: 42)

        let restored = NonogramGame(puzzle: plus, rules: .classic, restoring: game.snapshot)
        XCTAssertEqual(restored.board, game.board)
        XCTAssertEqual(restored.mistakes, 1)
        XCTAssertEqual(restored.elapsed, 42)
        XCTAssertEqual(restored.lockedCells, [position(0, 0)])
    }

    func testSnapshotForOtherPuzzleIsIgnored() {
        var game = NonogramGame(puzzle: plus, rules: .classic)
        game.mark(.filled, at: position(1, 1))
        let other = Puzzle(id: "other", pattern: [".#.", "###", ".#."])
        let restored = NonogramGame(puzzle: other, rules: .classic, restoring: game.snapshot)
        XCTAssertTrue(restored.board.storage.allSatisfy { $0 == .blank })
    }
}
