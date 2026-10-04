import NonogramKit
import SwiftUI
import Testing
@testable import PurrfectNonogram

@MainActor
struct ThemeTests {
    func makeDefaults() -> UserDefaults {
        let name = "ThemeTests-\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: name)!
        defaults.removePersistentDomain(forName: name)
        return defaults
    }

    @Test func defaultsToPastelAndSystem() {
        let manager = ThemeManager(defaults: makeDefaults())
        #expect(manager.palette == .pastel)
        #expect(manager.appearance == .system)
    }

    @Test func persistsSelection() {
        let defaults = makeDefaults()
        let manager = ThemeManager(defaults: defaults)
        manager.palette = .midnight
        manager.appearance = .dark

        let reloaded = ThemeManager(defaults: defaults)
        #expect(reloaded.palette == .midnight)
        #expect(reloaded.appearance == .dark)
    }

    @Test func themeFollowsColorScheme() {
        let manager = ThemeManager(defaults: makeDefaults())
        manager.palette = .coffee
        #expect(manager.theme(for: .dark) == AppTheme(palette: .coffee, isDark: true))
        #expect(manager.theme(for: .light) != manager.theme(for: .dark))
    }

    /// Her palet varyantının tüm hex değerleri geçerli olmalı (Color(hex:) geliştirmede assert eder).
    @Test(arguments: ThemePalette.allCases, [false, true])
    func paletteSpecsAreValidHex(palette: ThemePalette, isDark: Bool) {
        let spec = palette.spec(isDark: isDark)
        let values = Mirror(reflecting: spec).children.compactMap { $0.value as? String }
        #expect(values.count == 15)
        for value in values {
            #expect(RGBColor(hex: value) != nil, "\(palette) \(isDark): \(value)")
        }
    }
}

