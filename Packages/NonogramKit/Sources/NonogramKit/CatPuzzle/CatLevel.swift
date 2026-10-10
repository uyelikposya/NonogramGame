import Foundation

/// Kedi Bulmaca bölümü: NxN tahta N renge bölünmüş. Her renkte, her satırda ve her sütunda
/// tam bir kedi saklanır; kediler birbirine (çapraz dahil) değemez.
/// İçerik `Tools/generate_cat_levels.py` ile üretilir (tek çözümlü ve tahminsiz çözülebilir).
public struct CatLevel: Codable, Hashable, Identifiable, Sendable {
    public let id: String
    public let size: Int
    /// Her satır bir dize; her harf bir renk ("a" = 0. renk).
    public let regions: [String]
    /// Her satırdaki kedinin sütunu.
    public let solution: [Int]
    /// Her renge düşen kedi türü (katalogdaki tür kimliği); hepsi farklı.
    public let breeds: [String]
    /// En zor gereken çözüm kuralı (0: tek seçenek … 3: deneme zinciri).
    public let difficulty: Int

    /// Satır öncelikli renk dizini (`row * size + column`).
    public let regionMap: [Int]
    /// Her rengin kareleri (satır öncelikli dizinler).
    public let regionCells: [[Int]]

    private enum CodingKeys: String, CodingKey {
        case id, size, regions, solution, breeds, difficulty
    }

    public init(id: String, regions: [String], solution: [Int], breeds: [String], difficulty: Int = 0) {
        self.id = id
        self.size = regions.count
        self.regions = regions
        self.solution = solution
        self.breeds = breeds
        self.difficulty = difficulty
        let map = Self.map(regions)
        self.regionMap = map
        self.regionCells = Self.cells(map, count: regions.count)
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(String.self, forKey: .id)
        size = try container.decode(Int.self, forKey: .size)
        regions = try container.decode([String].self, forKey: .regions)
        solution = try container.decode([Int].self, forKey: .solution)
        breeds = try container.decode([String].self, forKey: .breeds)
        difficulty = try container.decodeIfPresent(Int.self, forKey: .difficulty) ?? 0
        let map = Self.map(regions)
        regionMap = map
        regionCells = Self.cells(map, count: size)
        guard regions.count == size, regions.allSatisfy({ $0.count == size }),
              solution.count == size, breeds.count == size,
              regionMap.allSatisfy({ (0..<size).contains($0) })
        else {
            throw DecodingError.dataCorruptedError(forKey: .regions, in: container, debugDescription: "\(id): hatalı boyut")
        }
    }

    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(id, forKey: .id)
        try container.encode(size, forKey: .size)
        try container.encode(regions, forKey: .regions)
        try container.encode(solution, forKey: .solution)
        try container.encode(breeds, forKey: .breeds)
        try container.encode(difficulty, forKey: .difficulty)
    }

    private static func map(_ regions: [String]) -> [Int] {
        let a = Int(UnicodeScalar("a").value)
        return regions.flatMap { row in row.unicodeScalars.map { Int($0.value) - a } }
    }

    private static func cells(_ map: [Int], count: Int) -> [[Int]] {
        var result = [[Int]](repeating: [], count: count)
        for (i, g) in map.enumerated() where (0..<count).contains(g) {
            result[g].append(i)
        }
        return result
    }

    public func region(at position: GridPosition) -> Int {
        regionMap[position.row * size + position.column]
    }

    public func isCat(_ position: GridPosition) -> Bool {
        solution[position.row] == position.column
    }

    /// Rengin kedisinin yeri.
    public func catPosition(ofRegion region: Int) -> GridPosition {
        let row = (0..<size).first { regionMap[$0 * size + solution[$0]] == region } ?? 0
        return GridPosition(row: row, column: solution[row])
    }

    public func cells(ofRegion region: Int) -> [GridPosition] {
        regionCells[region].map { GridPosition(row: $0 / size, column: $0 % size) }
    }
}

/// Paketlenmiş bölüm listesi (`cat_levels.json`).
public struct CatLevelPack: Codable, Sendable {
    public let levels: [CatLevel]

    public init(levels: [CatLevel]) {
        self.levels = levels
    }

    public static let empty = CatLevelPack(levels: [])

    public static func load(from bundle: Bundle, name: String = "cat_levels") throws -> CatLevelPack {
        guard let url = bundle.url(forResource: name, withExtension: "json") else {
            throw CocoaError(.fileNoSuchFile)
        }
        return try JSONDecoder().decode(CatLevelPack.self, from: Data(contentsOf: url))
    }

    public func level(withID id: String) -> CatLevel? {
        levels.first { $0.id == id }
    }

    /// 1'den başlayan bölüm numarası.
    public func number(of level: CatLevel) -> Int {
        (levels.firstIndex { $0.id == level.id } ?? 0) + 1
    }

    public func level(after level: CatLevel) -> CatLevel? {
        guard let index = levels.firstIndex(where: { $0.id == level.id }), index + 1 < levels.count else { return nil }
        return levels[index + 1]
    }
}
