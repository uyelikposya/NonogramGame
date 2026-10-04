import Foundation

/// Bir bulmacanın nasıl oynanacağı. Katalogda varsayılan kurallar tanımlanır,
/// tek tek bulmacalar bunları ezebilir (ör. süreli bir "boss" bölümü).
public struct GameRules: Hashable, Sendable {
    /// Her hamle çözüme göre anında kontrol edilir mi? `false` ise serbest (klasik kâğıt) mod:
    /// hata sayılmaz, tahta ipuçlarını sağlayınca bulmaca biter.
    public var checksMoves: Bool
    /// İzin verilen en fazla hata; `nil` sınırsız. Yalnızca `checksMoves` açıkken anlamlıdır.
    public var mistakeLimit: Int?
    /// Saniye cinsinden süre sınırı; `nil` süresiz.
    public var timeLimit: TimeInterval?
    /// İpucu tamamlanan satır/sütundaki boş kareler otomatik olarak X ile işaretlenir.
    public var autoCrossCompletedLines: Bool

    public init(
        checksMoves: Bool = true,
        mistakeLimit: Int? = 3,
        timeLimit: TimeInterval? = nil,
        autoCrossCompletedLines: Bool = true
    ) {
        self.checksMoves = checksMoves
        self.mistakeLimit = mistakeLimit
        self.timeLimit = timeLimit
        self.autoCrossCompletedLines = autoCrossCompletedLines
    }

    /// 3 can, süresiz.
    public static let classic = GameRules()
    /// Eğitici bölümler: hata sınırı yok.
    public static let relaxed = GameRules(mistakeLimit: nil)
}

extension GameRules: Codable {
    private enum CodingKeys: String, CodingKey {
        case checksMoves
        case mistakeLimit
        case timeLimitSeconds
        case autoCrossCompletedLines
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        let defaults = GameRules.classic
        checksMoves = try container.decodeIfPresent(Bool.self, forKey: .checksMoves) ?? defaults.checksMoves
        // Anahtar yoksa varsayılan, açıkça `null` ise sınırsız
        mistakeLimit = container.contains(.mistakeLimit)
            ? try container.decodeIfPresent(Int.self, forKey: .mistakeLimit)
            : defaults.mistakeLimit
        timeLimit = try container.decodeIfPresent(Int.self, forKey: .timeLimitSeconds).map(TimeInterval.init)
        autoCrossCompletedLines = try container.decodeIfPresent(Bool.self, forKey: .autoCrossCompletedLines)
            ?? defaults.autoCrossCompletedLines
    }

    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(checksMoves, forKey: .checksMoves)
        try container.encode(mistakeLimit, forKey: .mistakeLimit)
        try container.encode(timeLimit.map { Int($0) }, forKey: .timeLimitSeconds)
        try container.encode(autoCrossCompletedLines, forKey: .autoCrossCompletedLines)
    }
}
