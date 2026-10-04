import Foundation

/// Çözüm sonrası ortaya çıkan piksel görselin rengi. UI katmanı bunu SwiftUI `Color`'a çevirir.
public struct RGBColor: Hashable, Sendable {
    public let red: UInt8
    public let green: UInt8
    public let blue: UInt8

    public init(red: UInt8, green: UInt8, blue: UInt8) {
        self.red = red
        self.green = green
        self.blue = blue
    }

    /// `"#RRGGBB"` veya `"RRGGBB"`.
    public init?(hex: String) {
        let digits = hex.hasPrefix("#") ? String(hex.dropFirst()) : hex
        guard digits.count == 6, let value = UInt32(digits, radix: 16) else { return nil }
        self.init(
            red: UInt8((value >> 16) & 0xFF),
            green: UInt8((value >> 8) & 0xFF),
            blue: UInt8(value & 0xFF)
        )
    }

    public var hex: String {
        String(format: "#%02X%02X%02X", red, green, blue)
    }
}
