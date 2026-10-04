import Foundation

/// JSON'daki `{ "palette": {...}, "pixels": [...] }` biçimli piksel resim.
/// Bulmacaların çözüm görseli ve kedi türü portreleri bu biçimi kullanır.
public enum PixelArt {
    public static let emptyPixel: Character = "."

    public struct FormatError: Error, CustomStringConvertible {
        public let description: String
    }

    /// `.` boş kare, diğer her karakter `palette`teki bir renk.
    public static func artwork(palette paletteHex: [String: String], pixels: [String]) throws -> Matrix<RGBColor?> {
        var palette: [Character: RGBColor] = [:]
        for (key, hex) in paletteHex {
            guard key.count == 1, let symbol = key.first, symbol != emptyPixel else {
                throw FormatError(description: "palet anahtarı tek karakter olmalı ve '.' olamaz: \(key)")
            }
            guard let color = RGBColor(hex: hex) else {
                throw FormatError(description: "geçersiz renk \(hex)")
            }
            palette[symbol] = color
        }

        let cells = try pixels.map { (line: String) throws -> [RGBColor?] in
            try line.map { (symbol: Character) throws -> RGBColor? in
                if symbol == emptyPixel { return nil }
                guard let color = palette[symbol] else {
                    throw FormatError(description: "palette olmayan piksel '\(symbol)'")
                }
                return color
            }
        }
        guard let artwork = Matrix(cells) else {
            throw FormatError(description: "pixels boş olamaz ve tüm satırlar aynı uzunlukta olmalı")
        }
        guard artwork.storage.contains(where: { $0 != nil }) else {
            throw FormatError(description: "en az bir dolu kare olmalı")
        }
        return artwork
    }

    /// `{ "palette": ..., "pixels": ... }` nesnesini çözer.
    struct Payload: Decodable {
        let palette: [String: String]
        let pixels: [String]

        func artwork() throws -> Matrix<RGBColor?> {
            try PixelArt.artwork(palette: palette, pixels: pixels)
        }
    }
}
