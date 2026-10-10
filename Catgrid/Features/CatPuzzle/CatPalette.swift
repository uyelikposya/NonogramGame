import SwiftUI

/// Kedi Bulmaca'nın renk bölgeleri: 15 canlı, birbirinden kolay ayırt edilen renk.
/// Sıra önemli: küçük tahtalarda ilk renkler kullanılır, en ayrık olanlar başta.
enum CatPalette {
    static let colors: [Color] = [
        Color(red: 0.24, green: 0.68, blue: 0.64),  // deniz yeşili
        Color(red: 0.93, green: 0.48, blue: 0.68),  // pembe
        Color(red: 0.55, green: 0.42, blue: 0.82),  // mor
        Color(red: 0.37, green: 0.50, blue: 0.78),  // mavi
        Color(red: 0.66, green: 0.42, blue: 0.27),  // kahve
        Color(red: 0.55, green: 0.77, blue: 0.43),  // yeşil
        Color(red: 0.96, green: 0.63, blue: 0.32),  // turuncu
        Color(red: 0.86, green: 0.71, blue: 0.24),  // hardal
        Color(red: 0.58, green: 0.76, blue: 0.91),  // açık mavi
        Color(red: 0.90, green: 0.40, blue: 0.38),  // mercan
        Color(red: 0.98, green: 0.73, blue: 0.80),  // açık pembe
        Color(red: 0.40, green: 0.40, blue: 0.48),  // arduvaz
        Color(red: 0.76, green: 0.62, blue: 0.86),  // lila
        Color(red: 0.70, green: 0.86, blue: 0.74),  // nane
        Color(red: 0.80, green: 0.58, blue: 0.47),  // kiremit
    ]

    static func color(_ region: Int) -> Color {
        colors[region % colors.count]
    }
}
