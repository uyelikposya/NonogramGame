import SwiftUI

private struct ThemedScreen: ViewModifier {
    @Environment(\.appTheme) private var theme

    func body(content: Content) -> some View {
        content
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .background(theme.background.ignoresSafeArea())
            .toolbarBackground(theme.background, for: .navigationBar)
    }
}

/// Sistem başlığı tema rengini almadığı için başlık ortada tema rengiyle çizilir.
private struct ScreenTitle: ViewModifier {
    @Environment(\.appTheme) private var theme
    let title: Text

    func body(content: Content) -> some View {
        content
            .navigationTitle(title)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .principal) {
                    title
                        .font(.headline)
                        .foregroundStyle(theme.textPrimary)
                }
            }
    }
}

private struct CardBackground: ViewModifier {
    @Environment(\.appTheme) private var theme
    let fill: Color?
    let cornerRadius: CGFloat

    func body(content: Content) -> some View {
        let shape = RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
        content
            .background(shape.fill(fill ?? theme.surface))
            .overlay(shape.strokeBorder(theme.isDark ? theme.separator : .clear, lineWidth: 1))
            .shadow(color: theme.cardShadow, radius: 12, x: 0, y: 4)
    }
}

/// Uygulama geneli vurgu rengi ve yuvarlak yazı tipi. Sheet'lere ayrıca uygulanmalı.
private struct AppChrome: ViewModifier {
    @Environment(\.appTheme) private var theme

    func body(content: Content) -> some View {
        content
            .tint(theme.accent)
            .fontDesign(.rounded)
    }
}

extension View {
    func themedScreen() -> some View {
        modifier(ThemedScreen())
    }

    func screenTitle(_ title: LocalizedStringResource) -> some View {
        modifier(ScreenTitle(title: Text(title)))
    }

    /// İçerikten gelen (çevrilmeyecek) başlıklar için.
    func screenTitle(verbatim title: String) -> some View {
        modifier(ScreenTitle(title: Text(verbatim: title)))
    }

    func card(fill: Color? = nil, cornerRadius: CGFloat = 24) -> some View {
        modifier(CardBackground(fill: fill, cornerRadius: cornerRadius))
    }

    func appChrome() -> some View {
        modifier(AppChrome())
    }
}
