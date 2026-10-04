import Foundation

/// JSON'dan gelen çok dilli metin: `{ "en": "Paw", "tr": "Pati" }`.
/// Arayüz metinleri String Catalog'dan gelir; bu tip yalnızca içerik (bölüm/bulmaca adları) içindir.
public struct LocalizedText: Hashable, Sendable {
    public let translations: [String: String]

    public init(_ translations: [String: String]) {
        self.translations = translations
    }

    public var resolved: String {
        resolved(preferredLanguages: Bundle.main.preferredLocalizations)
    }

    public func resolved(preferredLanguages: [String]) -> String {
        for language in preferredLanguages {
            if let value = translations[language] { return value }
            // "tr-TR" gibi bölge kodlu dilleri "tr"ye indir
            if let base = language.split(separator: "-").first,
               let value = translations[String(base)] {
                return value
            }
        }
        return translations["en"] ?? translations.values.first ?? ""
    }
}

extension LocalizedText: Codable {
    public init(from decoder: Decoder) throws {
        translations = try decoder.singleValueContainer().decode([String: String].self)
    }

    public func encode(to encoder: Encoder) throws {
        var container = encoder.singleValueContainer()
        try container.encode(translations)
    }
}

extension LocalizedText: ExpressibleByDictionaryLiteral {
    public init(dictionaryLiteral elements: (String, String)...) {
        self.init(Dictionary(uniqueKeysWithValues: elements))
    }
}
