import XCTest
@testable import NonogramKit

final class LineClueTests: XCTestCase {
    func testCountsRuns() {
        XCTAssertEqual(LineClue.clue(for: [true, true, false, true, false]), [2, 1])
        XCTAssertEqual(LineClue.clue(for: [false, false]), [])
        XCTAssertEqual(LineClue.clue(for: [true, true, true]), [3])
    }

    func testSatisfactionIgnoresCrosses() {
        XCTAssertTrue(LineClue.isSatisfied([.filled, .crossed, .filled, .blank], by: [1, 1]))
        XCTAssertFalse(LineClue.isSatisfied([.filled, .filled, .blank, .blank], by: [1, 1]))
    }
}

final class LineSolverTests: XCTestCase {
    func testOverlapFindsCenter() {
        // 5 karede 4'lük blok: ortadaki 3 kare kesin dolu
        let solved = LineSolver.solve(Array(repeating: nil, count: 5), clue: [4])
        XCTAssertEqual(solved, [nil, true, true, true, nil])
    }

    func testEmptyClueClearsLine() {
        XCTAssertEqual(LineSolver.solve([nil, nil, nil], clue: []), [false, false, false])
    }

    func testExactFitSolvesWholeLine() {
        XCTAssertEqual(LineSolver.solve(Array(repeating: nil, count: 5), clue: [2, 2]), [true, true, false, true, true])
    }

    func testUsesKnownCells() {
        // Son kare dolu ve tek blok 2 ise blok sona yaslanır
        let solved = LineSolver.solve([nil, nil, nil, nil, true], clue: [2])
        XCTAssertEqual(solved, [false, false, false, true, true])
    }

    func testDetectsContradiction() {
        XCTAssertNil(LineSolver.solve([true, false, true], clue: [3]))
        XCTAssertNil(LineSolver.solve([true, nil], clue: []))
    }
}

final class PuzzleSolverTests: XCTestCase {
    func testSolvesUniquePuzzleLogically() {
        let puzzle = Puzzle(id: "heart", pattern: [".#.#.", "#####", "#####", ".###.", "..#.."])
        XCTAssertTrue(PuzzleSolver.isLogicallySolvable(puzzle))
        XCTAssertEqual(PuzzleSolver.countSolutions(rowClues: puzzle.rowClues, columnClues: puzzle.columnClues), 1)
    }

    func testDetectsAmbiguousPuzzle() {
        // Çapraz desen: ipuçları iki çözüme de uyar
        let puzzle = Puzzle(id: "diagonal", pattern: ["#.", ".#"])
        XCTAssertFalse(PuzzleSolver.isLogicallySolvable(puzzle))
        XCTAssertEqual(PuzzleSolver.countSolutions(rowClues: puzzle.rowClues, columnClues: puzzle.columnClues), 2)
    }
}
