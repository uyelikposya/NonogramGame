import Foundation

/// Tek bir satır/sütun için kesin çıkarım yapar: ipucuna uyan *tüm* yerleşimlerde
/// aynı kalan kareleri belirler. Dinamik programlama ile O(n·k·blok) çalışır,
/// 20x20 tahtalarda bile anlıktır.
///
/// Hücreler: `true` dolu, `false` boş, `nil` bilinmiyor.
public enum LineSolver {
    /// Çıkarımla güncellenmiş satırı döner; ipucuyla çelişen satırda `nil`.
    public static func solve(_ line: [Bool?], clue: [Int]) -> [Bool?]? {
        let length = line.count
        let blockCount = clue.count

        // Bir aralıkta kesin boş kare var mı, O(1) kontrol için önek toplamı
        var emptyPrefix = [Int](repeating: 0, count: length + 1)
        for index in 0..<length {
            emptyPrefix[index + 1] = emptyPrefix[index] + (line[index] == false ? 1 : 0)
        }

        func canBeEmpty(_ index: Int) -> Bool { line[index] != true }

        /// `block` numaralı blok `start` konumuna sığar mı (ardından gelen ayırıcı dahil)?
        func fits(_ block: Int, at start: Int) -> Bool {
            let end = start + clue[block]
            guard end <= length, emptyPrefix[end] - emptyPrefix[start] == 0 else { return false }
            return end == length || canBeEmpty(end)
        }

        /// Blok ve ayırıcısından sonraki ilk konum.
        func position(after block: Int, at start: Int) -> Int {
            min(start + clue[block] + 1, length)
        }

        // suffix[i][j]: i..<length kareleri j..<blockCount bloklarıyla doldurulabilir mi?
        var suffix = Array(repeating: Array(repeating: false, count: blockCount + 1), count: length + 1)
        suffix[length][blockCount] = true
        for index in stride(from: length - 1, through: 0, by: -1) {
            for block in 0...blockCount {
                var possible = canBeEmpty(index) && suffix[index + 1][block]
                if !possible, block < blockCount, fits(block, at: index) {
                    possible = suffix[position(after: block, at: index)][block + 1]
                }
                suffix[index][block] = possible
            }
        }
        guard suffix[0][0] else { return nil }

        // Baştan ilerleyerek yalnızca tam bir çözüme uzanan durumları işaretle
        var reachable = Array(repeating: Array(repeating: false, count: blockCount + 1), count: length + 1)
        reachable[0][0] = true
        var canFill = [Bool](repeating: false, count: length)
        var canClear = [Bool](repeating: false, count: length)

        for index in 0..<length {
            for block in 0...blockCount where reachable[index][block] {
                if canBeEmpty(index), suffix[index + 1][block] {
                    reachable[index + 1][block] = true
                    canClear[index] = true
                }
                guard block < blockCount, fits(block, at: index) else { continue }
                let next = position(after: block, at: index)
                guard suffix[next][block + 1] else { continue }
                reachable[next][block + 1] = true
                let end = index + clue[block]
                for cell in index..<end { canFill[cell] = true }
                if end < length { canClear[end] = true }
            }
        }

        return (0..<length).map { (index: Int) -> Bool? in
            switch (canFill[index], canClear[index]) {
            case (true, false): true
            case (false, true): false
            default: nil
            }
        }
    }
}
