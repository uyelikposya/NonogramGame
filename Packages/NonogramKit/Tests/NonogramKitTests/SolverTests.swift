import Testing
@testable import NonogramKit

struct LineClueTests {
    @Test func countsRuns() {
        #expect(LineClue.clue(for: [true, true, false, true, false]) == [2, 1])
        #expect(LineClue.clue(for: [false, false]) == [])
        #expect(LineClue.clue(for: [true, true, true]) == [3])
    }

    @Test func satisfactionIgnoresCrosses() {
        #expect(LineClue.isSatisfied([.filled, .crossed, .filled, .blank], by: [1, 1]))
        #expect(!LineClue.isSatisfied([.filled, .filled, .blank, .blank], by: [1, 1]))
    }
}

struct LineSolverTests {
    @Test func overlapFindsCenter() {
        // 5 karede 4'lük blok: ortadaki 3 kare kesin dolu
        let solved = LineSolver.solve(Array(repeating: nil, count: 5), clue: [4])
        #expect(solved == [nil, true, true, true, nil])
    }

    @Test func emptyClueClearsLine() {
        #expect(LineSolver.solve([nil, nil, nil], clue: []) == [false, false, false])
    }

    @Test func exactFitSolvesWholeLine() {
        #expect(LineSolver.solve(Array(repeating: nil, count: 5), clue: [2, 2]) == [true, true, false, true, true])
    }

    @Test func usesKnownCells() {
        // Son kare dolu ve tek blok 2 ise blok sona yaslanır
        let solved = LineSolver.solve([nil, nil, nil, nil, true], clue: [2])
        #expect(solved == [false, false, false, true, true])
    }

    @Test func detectsContradiction() {
        #expect(LineSolver.solve([true, false, true], clue: [3]) == nil)
        #expect(LineSolver.solve([true, nil], clue: []) == nil)
    }
}

struct PuzzleSolverTests {
    @Test func solvesUniquePuzzleLogically() {
        let puzzle = Puzzle(id: "heart", pattern: [".#.#.", "#####", "#####", ".###.", "..#.."])
        #expect(PuzzleSolver.isLogicallySolvable(puzzle))
        #expect(PuzzleSolver.countSolutions(rowClues: puzzle.rowClues, columnClues: puzzle.columnClues) == 1)
    }

    @Test func detectsAmbiguousPuzzle() {
        // Çapraz desen: ipuçları iki çözüme de uyar
        let puzzle = Puzzle(id: "diagonal", pattern: ["#.", ".#"])
        #expect(!PuzzleSolver.isLogicallySolvable(puzzle))
        #expect(PuzzleSolver.countSolutions(rowClues: puzzle.rowClues, columnClues: puzzle.columnClues) == 2)
    }
}
