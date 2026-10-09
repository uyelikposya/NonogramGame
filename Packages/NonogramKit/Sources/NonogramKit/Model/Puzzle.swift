import Foundation

/// Eğitici bölümlerde arayüzün hangi kuralı anlatacağı.
/// Metinler String Catalog'da `tutorial.<rawValue>.title` / `.body` anahtarlarıyla durur.
public enum TutorialLesson: String, Codable, Sendable, CaseIterable {
    case firstSquare
    case tapToFill
    case fullLines
    case emptyLines
    case markWithCross
    case multipleBlocks
    case overlap
    case edges
    case crossReference
    case mistakesAndLives
    case difficulty
    case graduation
}

/// Tek bir bulmaca. JSON'da çözüm, renkli piksel görsel olarak saklanır:
///
/// ```json
/// {
///   "id": "siamese-001",
///   "title": { "en": "Paw", "tr": "Pati" },
///   "palette": { "a": "#4A3B35", "b": "#F2D7C9" },
///   "pixels": [".a.a.", "aaaaa", ".bbb.", ".bbb.", "..b.."],
///   "rules": { "mistakeLimit": 3, "timeLimitSeconds": 300 }
/// }
/// ```
///
/// `.` boş kare, diğer her karakter `palette`teki bir renk ve dolu karedir.
/// İpuçları saklanmaz, çözümden hesaplanır; böylece veri ile ipucu asla çelişmez.
public struct Puzzle: Identifiable, Sendable {
    public static let emptyPixel: Character = PixelArt.emptyPixel

    public let id: String
    public let title: LocalizedText
    public let solution: Matrix<Bool>
    /// Çözüm tamamlanınca gösterilen görsel; boş karelerde `nil`.
    public let artwork: Matrix<RGBColor?>
    public let rowClues: [[Int]]
    public let columnClues: [[Int]]
    /// `nil` ise katalogdaki varsayılan kurallar geçerlidir.
    public let rulesOverride: GameRules?
    public let lesson: TutorialLesson?

    public var rows: Int { solution.rows }
    public var columns: Int { solution.columns }

    public init(
        id: String,
        title: LocalizedText,
        artwork: Matrix<RGBColor?>,
        rulesOverride: GameRules? = nil,
        lesson: TutorialLesson? = nil
    ) {
        self.id = id
        self.title = title
        self.artwork = artwork
        let solution = artwork.map { $0 != nil }
        self.solution = solution
        self.rowClues = (0..<solution.rows).map { LineClue.clue(for: solution.row($0)) }
        self.columnClues = (0..<solution.columns).map { LineClue.clue(for: solution.column($0)) }
        self.rulesOverride = rulesOverride
        self.lesson = lesson
    }

    /// Testler ve önizlemeler için tek renkli bulmaca: `["#.#", ".#."]`.
    public init(id: String, title: LocalizedText = ["en": "Test"], pattern: [String], rules: GameRules? = nil) {
        let ink = RGBColor(red: 0x33, green: 0x33, blue: 0x33)
        let cells = pattern.map { line in line.map { $0 == Self.emptyPixel ? nil : Optional(ink) } }
        guard let artwork = Matrix(cells) else { preconditionFailure("Geçersiz desen: \(pattern)") }
        self.init(id: id, title: title, artwork: artwork, rulesOverride: rules)
    }
}

extension Puzzle: Hashable {
    public static func == (lhs: Puzzle, rhs: Puzzle) -> Bool { lhs.id == rhs.id }
    public func hash(into hasher: inout Hasher) { hasher.combine(id) }
}

extension Puzzle: Decodable {
    private enum CodingKeys: String, CodingKey {
        case id, title, palette, pixels, rules, lesson
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        let id = try container.decode(String.self, forKey: .id)
        let paletteHex = try container.decode([String: String].self, forKey: .palette)
        let pixels = try container.decode([String].self, forKey: .pixels)

        let artwork: Matrix<RGBColor?>
        do {
            artwork = try PixelArt.artwork(palette: paletteHex, pixels: pixels)
        } catch {
            throw DecodingError.dataCorruptedError(forKey: .pixels, in: container, debugDescription: "\(id): \(error)")
        }

        self.init(
            id: id,
            title: try container.decode(LocalizedText.self, forKey: .title),
            artwork: artwork,
            rulesOverride: try container.decodeIfPresent(GameRules.self, forKey: .rules),
            lesson: try container.decodeIfPresent(TutorialLesson.self, forKey: .lesson)
        )
    }
}
