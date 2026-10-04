import NonogramKit
import XCTest
@testable import PurrfectNonogram

@MainActor
final class GameViewModelTests: XCTestCase {
    let puzzle = Puzzle(id: "bar", pattern: ["###", "...", "..."])
    let freeRules = GameRules(checksMoves: false, autoCrossCompletedLines: false)

    func position(_ row: Int, _ column: Int) -> GridPosition {
        GridPosition(row: row, column: column)
    }

    func testDragFillsOnlyBlankCells() {
        let viewModel = GameViewModel(puzzle: puzzle, rules: freeRules)
        viewModel.tool = .cross
        viewModel.tap(position(0, 1))

        viewModel.tool = .fill
        viewModel.dragBegan(at: position(0, 0))
        viewModel.dragMoved(to: position(0, 1))
        viewModel.dragMoved(to: position(0, 2))
        viewModel.dragEnded()

        XCTAssertEqual(viewModel.game.board.row(0), [.filled, .crossed, .filled])
    }

    func testDragStartingOnMarkErases() {
        let viewModel = GameViewModel(puzzle: puzzle, rules: freeRules)
        viewModel.tap(position(0, 0))
        viewModel.tap(position(0, 1))

        viewModel.dragBegan(at: position(0, 0))
        viewModel.dragMoved(to: position(0, 1))
        viewModel.dragMoved(to: position(0, 2))
        viewModel.dragEnded()

        XCTAssertEqual(viewModel.game.board.row(0), [.blank, .blank, .blank])
    }

    func testReportsCompletionOnce() {
        let date = Date(timeIntervalSinceReferenceDate: 1000)
        let viewModel = GameViewModel(puzzle: puzzle, rules: .classic, now: { date })
        var completions: [PuzzleCompletion] = []
        viewModel.onSolved = { completions.append($0) }

        viewModel.dragBegan(at: position(0, 0))
        viewModel.dragMoved(to: position(0, 1))
        viewModel.dragMoved(to: position(0, 2))
        viewModel.dragMoved(to: position(1, 2))
        viewModel.dragEnded()

        XCTAssertEqual(completions, [PuzzleCompletion(puzzleID: "bar", completedAt: date, elapsed: 0, mistakes: 0)])
        XCTAssertTrue(viewModel.isFinished)
    }

    func testMistakeIsExposedForFeedback() {
        let viewModel = GameViewModel(puzzle: puzzle, rules: .classic)
        viewModel.tap(position(2, 2))
        XCTAssertEqual(viewModel.lastMistake, position(2, 2))
        XCTAssertEqual(viewModel.game.mistakes, 1)
    }

    func testTracksActiveCellWhileDragging() {
        let viewModel = GameViewModel(puzzle: puzzle, rules: .classic)
        viewModel.dragBegan(at: position(0, 0))
        XCTAssertEqual(viewModel.activeCell, position(0, 0))
        viewModel.dragEnded()
        XCTAssertNil(viewModel.activeCell)
    }

    func testRestartResetsLostGame() {
        let viewModel = GameViewModel(puzzle: puzzle, rules: .classic)
        viewModel.tap(position(1, 0))
        viewModel.tap(position(1, 1))
        viewModel.tap(position(1, 2))
        XCTAssertEqual(viewModel.game.status, .lost(.outOfMistakes))

        viewModel.restart()
        XCTAssertEqual(viewModel.game.status, .playing)
        XCTAssertEqual(viewModel.game.mistakes, 0)
        XCTAssertNil(viewModel.lastMistake)
        viewModel.stop()
    }
}
