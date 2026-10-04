import SwiftUI
import UIKit

@MainActor
@Observable
final class ThemeManager {
    static let paletteKey = "theme.palette"
    static let appearanceKey = "theme.appearance"

    var palette: ThemePalette {
        didSet { defaults.set(palette.rawValue, forKey: Self.paletteKey) }
    }

    var appearance: AppearanceMode {
        didSet {
            guard appearance != oldValue else { return }
            defaults.set(appearance.rawValue, forKey: Self.appearanceKey)
            applyInterfaceStyle(animated: true)
        }
    }

    private let defaults: UserDefaults

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
        self.palette = defaults.string(forKey: Self.paletteKey).flatMap(ThemePalette.init(rawValue:)) ?? .pastel
        self.appearance = defaults.string(forKey: Self.appearanceKey).flatMap(AppearanceMode.init(rawValue:)) ?? .system
    }

    func theme(for colorScheme: ColorScheme) -> AppTheme {
        AppTheme(palette: palette, isDark: colorScheme == .dark)
    }

    /// `preferredColorScheme(nil)` sistem temasına her zaman geri dönmediği için
    /// stil doğrudan pencereye uygulanır.
    func applyInterfaceStyle(animated: Bool = false) {
        guard ProcessInfo.processInfo.environment["XCODE_RUNNING_FOR_PREVIEWS"] != "1" else { return }
        let style: UIUserInterfaceStyle = switch appearance {
        case .system: .unspecified
        case .light: .light
        case .dark: .dark
        }
        let windows = UIApplication.shared.connectedScenes
            .compactMap { $0 as? UIWindowScene }
            .flatMap(\.windows)

        for window in windows where window.overrideUserInterfaceStyle != style {
            if animated {
                UIView.transition(with: window, duration: 0.35, options: .transitionCrossDissolve) {
                    window.overrideUserInterfaceStyle = style
                }
            } else {
                window.overrideUserInterfaceStyle = style
            }
        }
    }
}
