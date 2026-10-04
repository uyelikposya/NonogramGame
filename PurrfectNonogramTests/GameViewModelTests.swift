import Foundation
import NonogramKit
import Testing
@testable import PurrfectNonogram

@MainActor
struct GameViewModelTests {
    let puzzle = Puzzle(id: "bar", pattern: ["###", "...", "..."])

    func position(_ row: Int, _ column: Int) -> GridPosition {
        GridPosition(row: row, column: column)
    }

    @Test func dragFillsOnlyBlankCells() {
        let viewModel = GameViewModel(puzzle: puzzle, rules: GameRules(checksMoves: false, autoCrossCompletedLines: false))
        viewModel.tool = .cross
        viewModel.tap(position(0, 1))

        viewModel.tool = .fill
        viewModel.dragBegan(at: position(0, 0))
        viewModel.dragMoved(to: position(0, 1))
        viewModel.dragMoved(to: position(0, 2))
        viewModel.dragEnded()

        #expect(viewModel.game.board.row(0) == [.filled, .crossed, .filled])
    }

    @Test func dragStartingOnMarkErases() {
        let viewModel = GameViewModel(puzzle: puzzle, rules: GameRules(checksMoves: false, autoCrossCompletedLines: false))
        viewModel.tap(position(0, 0))
        viewModel.tap(position(0, 1))

        viewModel.dragBegan(at: position(0, 0))
        viewModel.dragMoved(to: position(0, 1))
        viewModel.dragMoved(to: position(0, 2))
        viewModel.dragEnded()

        #expect(viewModel.game.board.row(0) == [.blank, .blank, .blank])
    }

    @Test func reportsCompletionOnce() {
        let date = Date(timeIntervalSinceReferenceDate: 1000)
        let viewModel = GameViewModel(puzzle: puzzle, rules: .classic, now: { date })
        var completions: [PuzzleCompletion] = []
        viewModel.onSolved = { completions.append($0) }

        viewModel.dragBegan(at: position(0, 0))
        viewModel.dragMoved(to: position(0, 1))
        viewModel.dragMoved(to: position(0, 2))
        viewModel.dragMoved(to: position(1, 2))
        viewModel.dragEnded()

        #expect(completions == [PuzzleCompletion(puzzleID: "bar", completedAt: date, elapsed: 0, mistakes: 0)])
        #expect(viewModel.isFinished)
    }

    @Test func mistakeIsExposedForFeedback() {
        let viewModel = GameViewModel(puzzle: puzzle, rules: .classic)
        viewModel.tap(position(2, 2))
        #expect(viewModel.lastMistake == position(2, 2))
        #expect(viewModel.game.mistakes == 1)
    }

    @Test func tracksActiveCellWhileDragging() {
        let viewModel = GameViewModel(puzzle: puzzle, rules: .classic)
        viewModel.dragBegan(at: position(0, 0))
        #expect(viewModel.activeCell == position(0, 0))
        viewModel.dragEnded()
        #expect(viewModel.activeCell == nil)
    }

    @Test func restartResetsLostGame() {
        let viewModel = GameViewModel(puzzle: puzzle, rules: .classic)
        viewModel.tap(position(1, 0))
        viewModel.tap(position(1, 1))
        viewModel.tap(position(1, 2))
        #expect(viewModel.game.status == .lost(.outOfMistakes))

        viewModel.restart()
        #expect(viewModel.game.status == .playing)
        #expect(viewModel.game.mistakes == 0)
        #expect(viewModel.lastMistake == nil)
        viewModel.stop()
    }
}
