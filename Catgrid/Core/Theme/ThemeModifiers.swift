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
    var subtitle: Text?

    func body(content: Content) -> some View {
        content
            .navigationTitle(title)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .principal) {
                    VStack(spacing: 0) {
                        title
                            .font(.headline)
                            .foregroundStyle(theme.textPrimary)
                        if let subtitle {
                            subtitle
                                .font(.caption)
                                .foregroundStyle(theme.textSecondary)
                        }
                    }
                    .lineLimit(1)
                    .minimumScaleFactor(0.8)
                    .accessibilityElement(children: .combine)
                    .accessibilityIdentifier("screen.title")
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

    /// Başlık + altında küçük bir satır (ör. tür adı ve "Bulmaca 3 / 16").
    func screenTitle(_ title: Text, subtitle: Text?) -> some View {
        modifier(ScreenTitle(title: title, subtitle: subtitle))
    }

    func card(fill: Color? = nil, cornerRadius: CGFloat = 24) -> some View {
        modifier(CardBackground(fill: fill, cornerRadius: cornerRadius))
    }

    func appChrome() -> some View {
        modifier(AppChrome())
    }
}
