import NonogramKit
import SwiftUI
import XCTest
@testable import PurrfectNonogram

@MainActor
final class ThemeTests: XCTestCase {
    func makeDefaults() -> UserDefaults {
        let name = "ThemeTests-\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: name)!
        defaults.removePersistentDomain(forName: name)
        return defaults
    }

    func testDefaultsToPastelAndSystem() {
        let manager = ThemeManager(defaults: makeDefaults())
        XCTAssertEqual(manager.palette, .pastel)
        XCTAssertEqual(manager.appearance, .system)
    }

    func testPersistsSelection() {
        let defaults = makeDefaults()
        let manager = ThemeManager(defaults: defaults)
        manager.palette = .midnight
        manager.appearance = .dark

        let reloaded = ThemeManager(defaults: defaults)
        XCTAssertEqual(reloaded.palette, .midnight)
        XCTAssertEqual(reloaded.appearance, .dark)
    }

    func testThemeFollowsColorScheme() {
        let manager = ThemeManager(defaults: makeDefaults())
        manager.palette = .coffee
        XCTAssertEqual(manager.theme(for: .dark), AppTheme(palette: .coffee, isDark: true))
        XCTAssertNotEqual(manager.theme(for: .light), manager.theme(for: .dark))
    }

    /// Her palet varyantının tüm hex değerleri geçerli olmalı (Color(hex:) geliştirmede assert eder).
    func testPaletteSpecsAreValidHex() {
        for palette in ThemePalette.allCases {
            for isDark in [false, true] {
                let values = Mirror(reflecting: palette.spec(isDark: isDark)).children.compactMap { $0.value as? String }
                XCTAssertEqual(values.count, 15)
                for value in values {
                    XCTAssertNotNil(RGBColor(hex: value), "\(palette) \(isDark): \(value)")
                }
            }
        }
    }
}
