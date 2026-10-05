import SwiftUI

/// Premium ve Altın Kart için ortak altın tonları (tüm temalarda aynı).
enum Gold {
    static let light = Color(hex: "#FFF1B8")
    static let bright = Color(hex: "#F7D774")
    static let mid = Color(hex: "#E5B53A")
    static let deep = Color(hex: "#C08A1E")
    static let dark = Color(hex: "#6B4A0E")

    /// Altın üzerindeki yazılar için koyu kahve (açık altın zeminde 7:1'in üzerinde kontrast).
    static let ink = Color(hex: "#4A3207")

    static let foil = LinearGradient(colors: [bright, mid, light, deep, bright], startPoint: .topLeading, endPoint: .bottomTrailing)
    static let frame = [bright, deep, light, mid]
}
