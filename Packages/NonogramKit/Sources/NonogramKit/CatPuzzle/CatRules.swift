import Foundation

/// "?" ipucu: neden ve uygulanınca ne olacağı.
public struct CatHint: Equatable, Sendable {
    public enum Kind: Equatable, Sendable {
        /// Bulunan kedinin satırı, sütunu, rengi ve komşularında başka kedi olamaz.
        case placedCat
        /// Bu satır/sütun/renkte kedi için tek yer kaldı (uygulanınca kedi konur).
        case onlySpot(CatGroup)
        /// k renk tamamen k satıra (sütuna) sığıyor: o satırlarda başka renge kedi düşmez.
        case regionsFillLines(axis: CatGroup.Axis, count: Int)
        /// k satırın (sütunun) adayları k renge ait: o renklerin geri kalanında kedi olamaz.
        case linesFillRegions(axis: CatGroup.Axis, count: Int)
        /// Buraya kedi konursa vurgulanan alanda kediye yer kalmaz.
        case wouldEmpty(CatGroup)
        /// Buraya kedi konursa birkaç adım sonra bir alanda kediye yer kalmaz.
        case deadEnd(CatGroup)
    }

    public let kind: Kind
    /// X konacak kareler (tek yer ipucunda kedinin karesi).
    public let cells: [GridPosition]
    /// Nedeni gösteren kareler (vurgulanır).
    public let focus: [GridPosition]
}

/// Satır, sütun ya da renk.
public struct CatGroup: Hashable, Sendable {
    public enum Axis: String, Sendable {
        case row
        case column
        case region
    }

    public let axis: Axis
    public let index: Int
}

/// Kedi Bulmaca kuralları ve mantık adımları. `Tools/generate_cat_levels.py` içindeki
/// `deduce` ile aynı sırayla çalışır; böylece her bölüm yalnızca bu ipuçlarıyla çözülebilir.
public enum CatRules {
    /// `index` karesine kedi konunca kedi olamayacak kareler (kendisi hariç).
    public static func attacked(by index: Int, in level: CatLevel) -> [Int] {
        let n = level.size
        let row = index / n
        let column = index % n
        var hit = Set<Int>()
        for i in 0..<n {
            hit.insert(row * n + i)
            hit.insert(i * n + column)
        }
        hit.formUnion(level.regionCells[level.regionMap[index]])
        for r in max(row - 1, 0)...min(row + 1, n - 1) {
            for c in max(column - 1, 0)...min(column + 1, n - 1) {
                hit.insert(r * n + c)
            }
        }
        hit.remove(index)
        return hit.sorted()
    }

    /// Bildiklerimize göre kedi olabilecek kareler: bulunan kedilerin etki alanı ve doğru
    /// konmuş X'ler elenir. Oyuncunun yanlışlıkla kedinin üstüne koyduğu X dikkate alınmaz.
    public static func candidates(in game: CatGame) -> [Bool] {
        let level = game.level
        var cand = [Bool](repeating: true, count: game.marks.count)
        for i in game.marks.indices {
            let position = GridPosition(row: i / level.size, column: i % level.size)
            switch game.marks[i] {
            case .cat:
                cand[i] = false
                for a in attacked(by: i, in: level) { cand[a] = false }
            case .cross, .wrong:
                if !level.isCat(position) { cand[i] = false }
            case .blank:
                break
            }
        }
        return cand
    }

    static func groups(of level: CatLevel) -> [(CatGroup, [Int])] {
        let n = level.size
        var result: [(CatGroup, [Int])] = []
        for r in 0..<n { result.append((CatGroup(axis: .row, index: r), (0..<n).map { r * n + $0 })) }
        for c in 0..<n { result.append((CatGroup(axis: .column, index: c), (0..<n).map { $0 * n + c })) }
        for g in 0..<n { result.append((CatGroup(axis: .region, index: g), level.regionCells[g])) }
        return result
    }

    public static func nextHint(in game: CatGame) -> CatHint? {
        let level = game.level
        let n = level.size
        let marks = game.marks
        func position(_ i: Int) -> GridPosition { GridPosition(row: i / n, column: i % n) }

        // Bulunan kedilerin etki alanında boş kare kaldıysa önce onu göster
        for i in marks.indices where marks[i] == .cat {
            let blanks = attacked(by: i, in: level).filter { marks[$0] == .blank }
            if !blanks.isEmpty {
                return CatHint(kind: .placedCat, cells: blanks.map(position), focus: [position(i)])
            }
        }

        var cand = candidates(in: game)
        let allGroups = groups(of: level)
        let closed: [Bool] = allGroups.map { _, cells in cells.contains { marks[$0] == .cat } }
        let open = allGroups.indices.filter { !closed[$0] }

        for _ in 0..<(n * n) {
            // 0: tek yer
            for g in open {
                let live = allGroups[g].1.filter { cand[$0] }
                if live.isEmpty { return nil }
                if live.count == 1 {
                    return CatHint(kind: .onlySpot(allGroups[g].0), cells: [position(live[0])], focus: allGroups[g].1.map(position))
                }
            }
            // 1: renk ↔ satır/sütun kısıtlaması
            if let step = confinement(level: level, cand: cand, marks: marks) {
                let visible = step.removed.filter { marks[$0] == .blank }
                if !visible.isEmpty {
                    return CatHint(kind: step.kind, cells: visible.map(position), focus: step.focus.map(position))
                }
                for i in step.removed { cand[i] = false }
                continue
            }
            // 2: buraya kedi konursa bir alan boşalır
            if case let (cell, group)? = wouldEmpty(level: level, cand: cand, groups: allGroups, open: open) {
                if marks[cell] == .blank {
                    return CatHint(kind: .wouldEmpty(allGroups[group].0), cells: [position(cell)], focus: allGroups[group].1.map(position))
                }
                cand[cell] = false
                continue
            }
            // 3: kısa deneme zinciri
            if case let (cell, group)? = deadEnd(level: level, cand: cand, groups: allGroups, open: open) {
                if marks[cell] == .blank {
                    return CatHint(kind: .deadEnd(allGroups[group].0), cells: [position(cell)], focus: allGroups[group].1.map(position))
                }
                cand[cell] = false
                continue
            }
            return nil
        }
        return nil
    }

    private struct Confinement {
        let kind: CatHint.Kind
        let removed: [Int]
        let focus: [Int]
    }

    /// Python'daki `rule_confinement` ile aynı sırada arar.
    private static func confinement(level: CatLevel, cand: [Bool], marks: [CatMark]) -> Confinement? {
        let n = level.size
        let catCells = marks.indices.filter { marks[$0] == .cat }
        let foundRegions = Set(catCells.map { level.regionMap[$0] })
        let openRegions = (0..<n).filter { !foundRegions.contains($0) }
        let liveCells = cand.indices.filter { cand[$0] }
        var regionCells: [Int: [Int]] = [:]
        for g in openRegions { regionCells[g] = liveCells.filter { level.regionMap[$0] == g } }

        for axis in [CatGroup.Axis.row, .column] {
            func line(_ i: Int) -> Int { axis == .row ? i / n : i % n }
            let usedLines = Set(catCells.map(line))
            let openLines = (0..<n).filter { !usedLines.contains($0) }
            var lineCells: [Int: [Int]] = [:]
            for l in openLines { lineCells[l] = liveCells.filter { line($0) == l } }

            for k in 1...3 {
                for combo in combinations(openRegions, k) {
                    let lines = Set(combo.flatMap { regionCells[$0] ?? [] }.map(line))
                    if lines.count == k {
                        let removed = lines.sorted().flatMap { lineCells[$0] ?? [] }.filter { !combo.contains(level.regionMap[$0]) }
                        if !removed.isEmpty {
                            let focus = combo.flatMap { level.regionCells[$0] }
                            return Confinement(kind: .regionsFillLines(axis: axis, count: k), removed: removed.sorted(), focus: focus)
                        }
                    }
                }
                for combo in combinations(openLines, k) {
                    let regs = Set(combo.flatMap { lineCells[$0] ?? [] }.map { level.regionMap[$0] })
                    if regs.count == k {
                        let removed = regs.sorted().flatMap { regionCells[$0] ?? [] }.filter { !combo.contains(line($0)) }
                        if !removed.isEmpty {
                            let focus = (0..<(n * n)).filter { combo.contains(line($0)) }
                            return Confinement(kind: .linesFillRegions(axis: axis, count: k), removed: removed.sorted(), focus: focus)
                        }
                    }
                }
            }
        }
        return nil
    }

    private static func wouldEmpty(level: CatLevel, cand: [Bool], groups: [(CatGroup, [Int])], open: [Int]) -> (Int, Int)? {
        for cell in cand.indices where cand[cell] {
            var hit = Set(attacked(by: cell, in: level))
            hit.insert(cell)
            for g in open where !groups[g].1.contains(cell) {
                let live = groups[g].1.filter { cand[$0] }
                if live.allSatisfy({ hit.contains($0) }) {
                    return (cell, g)
                }
            }
        }
        return nil
    }

    private static func deadEnd(level: CatLevel, cand: [Bool], groups: [(CatGroup, [Int])], open: [Int]) -> (Int, Int)? {
        let n = level.size
        for cell in cand.indices where cand[cell] {
            var trial = cand
            var closed = Set<Int>()
            func place(_ i: Int) {
                trial[i] = false
                for a in attacked(by: i, in: level) { trial[a] = false }
                for g in open where groups[g].1.contains(i) { closed.insert(g) }
            }
            place(cell)
            var empty: Int?
            for _ in 0..<n {
                var changed = false
                for g in open where !closed.contains(g) {
                    let live = groups[g].1.filter { trial[$0] }
                    if live.isEmpty {
                        empty = g
                        break
                    }
                    if live.count == 1 {
                        place(live[0])
                        changed = true
                    }
                }
                if empty != nil || !changed { break }
            }
            if let empty {
                return (cell, empty)
            }
        }
        return nil
    }

    private static func combinations(_ items: [Int], _ k: Int) -> [[Int]] {
        guard k > 0 else { return [[]] }
        guard items.count >= k else { return [] }
        var result: [[Int]] = []
        func rec(_ start: Int, _ current: [Int]) {
            if current.count == k {
                result.append(current)
                return
            }
            guard start < items.count else { return }
            for i in start..<items.count {
                rec(i + 1, current + [items[i]])
            }
        }
        rec(0, [])
        return result
    }
}
