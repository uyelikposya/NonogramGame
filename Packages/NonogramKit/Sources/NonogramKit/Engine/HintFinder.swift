import Foundation

/// Oyuncuya "şu satırda kesin bir hamle var" diyebilmek için tahtadaki bilgiyle
/// tek başına çözülebilen bir satır ya da sütun bulur. Cevabı söylemez, yalnızca yeri gösterir.
public enum HintFinder {
    public enum Axis: String, Sendable {
        case row
        case column
    }

    public struct Hint: Equatable, Sendable {
        public let axis: Axis
        public let index: Int
        /// Bu çizgide mantıkla kesinleşen ama henüz işaretlenmemiş kare sayısı.
        public let newCells: Int

        public init(axis: Axis, index: Int, newCells: Int) {
            self.axis = axis
            self.index = index
            self.newCells = newCells
        }
    }

    /// En çok yeni dolu kare kesinleştiren çizgi; eşitlikte önce satırlar, sonra küçük sıra.
    /// Kesin hamle yoksa ya da tahtada çelişki varsa `nil`.
    public static func bestHint(board: Matrix<CellState>, puzzle: Puzzle) -> Hint? {
        let known = board.map { state -> Bool? in
            switch state {
            case .filled: true
            case .crossed: false
            case .blank: nil
            }
        }
        var best: Hint?
        var bestScore = 0
        func consider(_ line: [Bool?], clue: [Int], axis: Axis, index: Int) {
            guard line.contains(where: { $0 == nil }),
                  let solved = LineSolver.solve(line, clue: clue)
            else { return }
            let fills = zip(line, solved).filter { $0 == nil && $1 == true }.count
            let crosses = zip(line, solved).filter { $0 == nil && $1 == false }.count
            // Dolu kare bulduran çizgiler önce; yalnızca X kesinleşiyorsa o da işe yarar
            let score = fills * 100 + crosses
            guard score > 0, score > bestScore else { return }
            bestScore = score
            best = Hint(axis: axis, index: index, newCells: fills + crosses)
        }
        for row in 0..<known.rows {
            consider(known.row(row), clue: puzzle.rowClues[row], axis: .row, index: row)
        }
        for column in 0..<known.columns {
            consider(known.column(column), clue: puzzle.columnClues[column], axis: .column, index: column)
        }
        return best
    }
}
