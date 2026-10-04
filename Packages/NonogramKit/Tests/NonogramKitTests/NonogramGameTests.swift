import Testing
@testable import NonogramKit

struct NonogramGameTests {
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

    @Test func correctFillsWin() {
        var game = NonogramGame(puzzle: plus, rules: .classic)
        fillAll(&game)
        #expect(game.status == .won)
        #expect(game.mistakes == 0)
        #expect(game.progress == 1)
    }

    @Test func wrongFillIsMistakeAndLocksCorrection() {
        var game = NonogramGame(puzzle: plus, rules: .classic)
        #expect(game.toggle(at: position(0, 0), with: .fill) == .mistake)
        #expect(game.board[position(0, 0)] == .crossed)
        #expect(game.remainingMistakes == 2)
        // Kilitli kare değiştirilemez
        #expect(game.toggle(at: position(0, 0), with: .cross) == .ignored)
    }

    @Test func wrongCrossRevealsFilledCell() {
        var game = NonogramGame(puzzle: plus, rules: .classic)
        #expect(game.toggle(at: position(1, 1), with: .cross) == .mistake)
        #expect(game.board[position(1, 1)] == .filled)
    }

    @Test func losesAfterMistakeLimit() {
        var game = NonogramGame(puzzle: plus, rules: .classic)
        game.mark(.filled, at: position(0, 0))
        game.mark(.filled, at: position(0, 2))
        #expect(game.mark(.filled, at: position(2, 0)) == .failed(.outOfMistakes))
        #expect(game.status == .lost(.outOfMistakes))
        #expect(game.mark(.filled, at: position(1, 1)) == .ignored)

        game.revive()
        #expect(game.status == .playing)
        #expect(game.remainingMistakes == 1)
    }

    @Test func autoCrossesCompletedLine() {
        var game = NonogramGame(puzzle: plus, rules: .classic)
        game.mark(.filled, at: position(0, 1))
        #expect(game.board[position(0, 0)] == .crossed)
        #expect(game.board[position(0, 2)] == .crossed)
        #expect(game.isRowSatisfied(0))
    }

    @Test func undoRevertsMoveWithAutoCrosses() {
        var game = NonogramGame(puzzle: plus, rules: .classic)
        game.mark(.filled, at: position(0, 1))
        #expect(game.undo())
        #expect(game.board.storage.allSatisfy { $0 == .blank })
        #expect(!game.canUndo)
    }

    @Test func toggleDoesNotOverwriteOtherMark() {
        var game = NonogramGame(puzzle: plus, rules: GameRules(checksMoves: false))
        game.toggle(at: position(0, 0), with: .cross)
        #expect(game.toggle(at: position(0, 0), with: .fill) == .ignored)
        #expect(game.toggle(at: position(0, 0), with: .cross) == .changed)
        #expect(game.board[position(0, 0)] == .blank)
    }

    @Test func freeModeAllowsWrongMarksAndWinsOnClues() {
        var game = NonogramGame(puzzle: plus, rules: GameRules(checksMoves: false, autoCrossCompletedLines: false))
        #expect(game.mark(.filled, at: position(0, 0)) == .changed)
        #expect(game.mistakes == 0)
        game.mark(.blank, at: position(0, 0))
        fillAll(&game)
        #expect(game.status == .won)
    }

    @Test func timeLimitEndsGame() {
        var game = NonogramGame(puzzle: plus, rules: GameRules(timeLimit: 10))
        game.advanceTime(by: 6)
        #expect(game.remainingTime == 4)
        #expect(game.advanceTime(by: 6) == .failed(.outOfTime))
        #expect(game.remainingTime == 0)
    }

    @Test func snapshotRestoresProgress() {
        var game = NonogramGame(puzzle: plus, rules: .classic)
        game.mark(.filled, at: position(1, 0))
        game.mark(.filled, at: position(0, 0))
        game.advanceTime(by: 42)

        let restored = NonogramGame(puzzle: plus, rules: .classic, restoring: game.snapshot)
        #expect(restored.board == game.board)
        #expect(restored.mistakes == 1)
        #expect(restored.elapsed == 42)
        #expect(restored.lockedCells == [position(0, 0)])
    }

    @Test func snapshotForOtherPuzzleIsIgnored() {
        var game = NonogramGame(puzzle: plus, rules: .classic)
        game.mark(.filled, at: position(1, 1))
        let other = Puzzle(id: "other", pattern: [".#.", "###", ".#."])
        let restored = NonogramGame(puzzle: other, rules: .classic, restoring: game.snapshot)
        #expect(restored.board.storage.allSatisfy { $0 == .blank })
    }
}
