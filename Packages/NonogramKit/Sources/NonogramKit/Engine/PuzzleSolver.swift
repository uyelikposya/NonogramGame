import Foundation

/// İçerik doğrulama ve ileride ipucu (hint) sistemi için çözücü.
///
/// Kalite kuralı: yayınlanan her bulmaca **yalnızca satır mantığıyla** (tahmin yapmadan)
/// çözülebilmeli. `isLogicallySolvable` bunu, `countSolutions` ise benzersizliği kontrol eder.
public enum PuzzleSolver {
    /// Satır ve sütun çıkarımlarını değişiklik kalmayana kadar tekrarlar.
    /// Çelişki bulunursa `false` döner.
    @discardableResult
    public static func propagate(_ grid: inout Matrix<Bool?>, rowClues: [[Int]], columnClues: [[Int]]) -> Bool {
        var dirtyRows = Set(0..<grid.rows)
        var dirtyColumns = Set(0..<grid.columns)

        while !dirtyRows.isEmpty || !dirtyColumns.isEmpty {
            for row in dirtyRows.sorted() {
                dirtyRows.remove(row)
                guard let solved = LineSolver.solve(grid.row(row), clue: rowClues[row]) else { return false }
                for column in 0..<grid.columns where grid[row, column] != solved[column] {
                    grid[row, column] = solved[column]
                    dirtyColumns.insert(column)
                }
            }
            for column in dirtyColumns.sorted() {
                dirtyColumns.remove(column)
                guard let solved = LineSolver.solve(grid.column(column), clue: columnClues[column]) else { return false }
                for row in 0..<grid.rows where grid[row, column] != solved[row] {
                    grid[row, column] = solved[row]
                    dirtyRows.insert(row)
                }
            }
        }
        return true
    }

    /// Tahmin yapmadan çözülebiliyorsa çözümü döner.
    public static func solveLogically(rowClues: [[Int]], columnClues: [[Int]]) -> Matrix<Bool>? {
        var grid = Matrix<Bool?>(rows: rowClues.count, columns: columnClues.count, repeating: nil)
        guard propagate(&grid, rowClues: rowClues, columnClues: columnClues) else { return nil }
        guard grid.storage.allSatisfy({ $0 != nil }) else { return nil }
        return grid.map { $0 ?? false }
    }

    public static func isLogicallySolvable(_ puzzle: Puzzle) -> Bool {
        solveLogically(rowClues: puzzle.rowClues, columnClues: puzzle.columnClues) == puzzle.solution
    }

    /// Çözüm sayısını `limit`e kadar sayar (benzersizlik için `limit: 2` yeterli).
    public static func countSolutions(rowClues: [[Int]], columnClues: [[Int]], limit: Int = 2) -> Int {
        let grid = Matrix<Bool?>(rows: rowClues.count, columns: columnClues.count, repeating: nil)
        return countSolutions(grid, rowClues: rowClues, columnClues: columnClues, limit: limit)
    }

    private static func countSolutions(_ grid: Matrix<Bool?>, rowClues: [[Int]], columnClues: [[Int]], limit: Int) -> Int {
        var grid = grid
        guard propagate(&grid, rowClues: rowClues, columnClues: columnClues) else { return 0 }
        guard let guess = grid.storage.firstIndex(where: { $0 == nil }) else { return 1 }

        var total = 0
        for value in [true, false] {
            var branch = grid
            branch[guess / grid.columns, guess % grid.columns] = value
            total += countSolutions(branch, rowClues: rowClues, columnClues: columnClues, limit: limit - total)
            if total >= limit { break }
        }
        return total
    }
}
