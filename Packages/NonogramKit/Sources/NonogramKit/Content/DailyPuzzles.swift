import Foundation

/// Takvim günü (yerel saat). Günlük bulmacanın kimliği ve seri hesabı için.
public struct DayKey: Hashable, Comparable, Sendable {
    public let year: Int
    public let month: Int
    public let day: Int

    public init(year: Int, month: Int, day: Int) {
        self.year = year
        self.month = month
        self.day = day
    }

    public init(_ date: Date, calendar: Calendar = .current) {
        let parts = calendar.dateComponents([.year, .month, .day], from: date)
        self.init(year: parts.year ?? 2026, month: parts.month ?? 1, day: parts.day ?? 1)
    }

    /// "daily-2026-10-09" biçimindeki bulmaca kimliğinden.
    public init?(puzzleID: String) {
        guard puzzleID.hasPrefix(DailyPuzzles.idPrefix) else { return nil }
        let parts = puzzleID.dropFirst(DailyPuzzles.idPrefix.count).split(separator: "-").compactMap { Int($0) }
        guard parts.count == 3 else { return nil }
        self.init(year: parts[0], month: parts[1], day: parts[2])
    }

    public var puzzleID: String {
        DailyPuzzles.idPrefix + String(format: "%04d-%02d-%02d", year, month, day)
    }

    /// Takvimden bağımsız gün numarası (proleptik Gregoryen); ardışık günler ardışık sayılardır.
    public var dayNumber: Int {
        let y = month <= 2 ? year - 1 : year
        let era = (y >= 0 ? y : y - 399) / 400
        let yoe = y - era * 400
        let mp = (month + 9) % 12
        let doy = (153 * mp + 2) / 5 + day - 1
        let doe = yoe * 365 + yoe / 4 - yoe / 100 + doy
        return era * 146_097 + doe
    }

    public var date: Date {
        Calendar(identifier: .gregorian).date(from: DateComponents(year: year, month: month, day: day)) ?? Date()
    }

    public static func < (lhs: DayKey, rhs: DayKey) -> Bool {
        lhs.dayNumber < rhs.dayNumber
    }
}

/// Günlük bulmaca havuzu: her gün herkes aynı bulmacayı oynar; havuz bitince başa döner.
public struct DailyPuzzles: Sendable {
    public static let idPrefix = "daily-"

    public let pool: [Puzzle]

    public init(pool: [Puzzle]) {
        self.pool = pool
    }

    public static let empty = DailyPuzzles(pool: [])

    public static func load(from bundle: Bundle, name: String = "daily") throws -> DailyPuzzles {
        guard let url = bundle.url(forResource: name, withExtension: "json") else {
            throw CatalogError.missingResource(name)
        }
        let file = try JSONDecoder().decode(ChapterFile.self, from: Data(contentsOf: url))
        return DailyPuzzles(pool: file.puzzles)
    }

    public static func isDaily(_ puzzleID: String) -> Bool {
        puzzleID.hasPrefix(idPrefix)
    }

    /// O günün bulmacası; kimliği güne özeldir ("daily-2026-10-09") ki her gün ayrı kaydedilsin.
    public func puzzle(for day: DayKey) -> Puzzle? {
        guard !pool.isEmpty else { return nil }
        let count = pool.count
        let source = pool[((day.dayNumber % count) + count) % count]
        return Puzzle(id: day.puzzleID, title: source.title, artwork: source.artwork)
    }

    public func puzzle(withID id: String) -> Puzzle? {
        DayKey(puzzleID: id).flatMap(puzzle(for:))
    }

    /// Bugünden geriye kesintisiz çözülen gün sayısı. Bugün henüz çözülmediyse dünden sayılır
    /// (seri gün bitene kadar bozulmaz).
    public static func streak(solvedDays: Set<DayKey>, today: DayKey) -> Int {
        let numbers = Set(solvedDays.map(\.dayNumber))
        var current = numbers.contains(today.dayNumber) ? today.dayNumber : today.dayNumber - 1
        var count = 0
        while numbers.contains(current) {
            count += 1
            current -= 1
        }
        return count
    }
}
