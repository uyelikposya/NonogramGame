import Foundation

/// `catalog.json` + bölüm başına bir JSON dosyasından `LevelCatalog` oluşturur.
///
/// Bölüm dosyaları ayrı tutulur: 460 bulmacayı tek dosyada düzenlemek zor, ayrıca içerik
/// ekibi her türü bağımsız hazırlayıp doğrulayabilir.
public enum CatalogLoader {
    /// - Parameter chapterData: Dosya adına göre bölüm verisini döner; dosya henüz yoksa `nil`
    ///   (içerik üretimi sürerken bölüm boş görünür).
    public static func load(catalogData: Data, chapterData: (String) throws -> Data?) throws -> LevelCatalog {
        let decoder = JSONDecoder()
        let manifest = try decoder.decode(CatalogManifest.self, from: catalogData)
        guard manifest.schemaVersion <= LevelCatalog.supportedSchemaVersion else {
            throw CatalogError.unsupportedSchema(manifest.schemaVersion)
        }

        let chapters = try manifest.chapters.map { (entry: CatalogManifest.Entry) throws -> Chapter in
            var puzzles: [Puzzle] = []
            if let data = try chapterData(entry.file) {
                let file = try decoder.decode(ChapterFile.self, from: data)
                guard file.chapterID == entry.id else {
                    throw CatalogError.chapterMismatch(expected: entry.id, found: file.chapterID)
                }
                puzzles = file.puzzles
            }
            return Chapter(
                id: entry.id,
                kind: entry.kind,
                title: entry.title,
                subtitle: entry.subtitle,
                accentColor: entry.accentColor.flatMap(RGBColor.init(hex:)),
                expectedPuzzleCount: entry.expectedPuzzleCount ?? puzzles.count,
                puzzles: puzzles
            )
        }
        return try LevelCatalog(chapters: chapters, defaultRules: manifest.defaultRules ?? .classic)
    }

    public static func load(from bundle: Bundle, catalogName: String = "catalog") throws -> LevelCatalog {
        guard let catalogURL = bundle.url(forResource: catalogName, withExtension: "json") else {
            throw CatalogError.missingResource(catalogName)
        }
        return try load(catalogData: Data(contentsOf: catalogURL)) { file in
            try bundle.url(forResource: file, withExtension: "json").map { try Data(contentsOf: $0) }
        }
    }
}

// MARK: - JSON şeması

struct CatalogManifest: Decodable {
    struct Entry: Decodable {
        let id: String
        let kind: Chapter.Kind
        let title: LocalizedText
        let subtitle: LocalizedText?
        let accentColor: String?
        let file: String
        /// İsteğe bağlı: içerik hazırlanırken planlanan sayı. Yoksa dosyadaki bulmaca sayısı kullanılır.
        let expectedPuzzleCount: Int?
    }

    let schemaVersion: Int
    let defaultRules: GameRules?
    let chapters: [Entry]
}

struct ChapterFile: Decodable {
    let schemaVersion: Int
    let chapterID: String
    let puzzles: [Puzzle]
}
