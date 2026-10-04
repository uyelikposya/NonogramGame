import NonogramKit
import SwiftUI

/// Anlamsal renk tokenları. View'lar ham renk kullanmaz, yalnızca bunları okur.
struct AppTheme: Equatable {
    let palette: ThemePalette
    let isDark: Bool

    let background: Color
    let surface: Color
    let surfaceMuted: Color
    let separator: Color

    let textPrimary: Color
    let textSecondary: Color

    let accent: Color
    let onAccent: Color

    /// Tahta
    let cellFilled: Color
    let cellCross: Color
    let gridLine: Color
    let gridLineMajor: Color
    /// Parmağın altındaki satır/sütun
    let highlight: Color

    let mistake: Color
    let success: Color

    var cardShadow: Color { isDark ? .clear : textPrimary.opacity(0.08) }

    init(palette: ThemePalette, isDark: Bool) {
        let spec = palette.spec(isDark: isDark)
        self.palette = palette
        self.isDark = isDark
        background = Color(hex: spec.background)
        surface = Color(hex: spec.surface)
        surfaceMuted = Color(hex: spec.surfaceMuted)
        separator = Color(hex: spec.separator)
        textPrimary = Color(hex: spec.textPrimary)
        textSecondary = Color(hex: spec.textSecondary)
        accent = Color(hex: spec.accent)
        onAccent = Color(hex: spec.onAccent)
        cellFilled = Color(hex: spec.cellFilled)
        cellCross = Color(hex: spec.cellCross)
        gridLine = Color(hex: spec.gridLine)
        gridLineMajor = Color(hex: spec.gridLineMajor)
        highlight = Color(hex: spec.highlight)
        mistake = Color(hex: spec.mistake)
        success = Color(hex: spec.success)
    }

    static let `default` = AppTheme(palette: .pastel, isDark: false)
}

private struct AppThemeKey: EnvironmentKey {
    static let defaultValue = AppTheme.default
}

extension EnvironmentValues {
    /// Kök görünüm, seçili palet ve pencerenin renk şemasından üretip enjekte eder.
    var appTheme: AppTheme {
        get { self[AppThemeKey.self] }
        set { self[AppThemeKey.self] = newValue }
    }
}

extension Color {
    init(_ color: RGBColor) {
        self.init(red: Double(color.red) / 255, green: Double(color.green) / 255, blue: Double(color.blue) / 255)
    }

    /// Yalnızca derleme zamanında bilinen palet sabitleri için; hatalı hex geliştirmede hemen yakalanır.
    init(hex: String) {
        guard let color = RGBColor(hex: hex) else {
            assertionFailure("Geçersiz renk: \(hex)")
            self = .gray
            return
        }
        self.init(color)
    }
}
