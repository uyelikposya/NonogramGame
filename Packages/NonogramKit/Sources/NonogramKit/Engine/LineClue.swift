import Foundation

public enum LineClue {
    /// Bir satır/sütundaki ardışık dolu blokların uzunlukları.
    /// Tamamen boş satır için `[]` döner (arayüz "0" gösterir).
    public static func clue(for line: [Bool]) -> [Int] {
        var clue: [Int] = []
        var run = 0
        for filled in line {
            if filled {
                run += 1
            } else if run > 0 {
                clue.append(run)
                run = 0
            }
        }
        if run > 0 { clue.append(run) }
        return clue
    }

    /// Oyuncunun işaretleri ipucunu tam olarak sağlıyor mu?
    public static func isSatisfied(_ line: [CellState], by clue: [Int]) -> Bool {
        self.clue(for: line.map { $0 == .filled }) == clue
    }
}
