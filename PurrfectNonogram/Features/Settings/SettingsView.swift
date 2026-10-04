import SwiftUI
import UIKit

enum SettingsKeys {
    static let haptics = "settings.haptics"
}

@MainActor
struct SettingsView: View {
    @Environment(ThemeManager.self) private var themeManager
    @Environment(AppModel.self) private var model
    @Environment(\.appTheme) private var theme
    @Environment(\.colorScheme) private var colorScheme
    @Environment(\.openURL) private var openURL
    @AppStorage(SettingsKeys.haptics) private var hapticsEnabled = true
    @State private var isConfirmingReset = false

    private let paletteColumns = [GridItem(.flexible(), spacing: 12), GridItem(.flexible(), spacing: 12)]

    var body: some View {
        @Bindable var themeManager = themeManager
        ScrollView {
            VStack(alignment: .leading, spacing: 28) {
                section("Color Palette") {
                    LazyVGrid(columns: paletteColumns, spacing: 12) {
                        ForEach(ThemePalette.allCases) { palette in
                            Button {
                                withAnimation(.easeInOut(duration: 0.3)) { themeManager.palette = palette }
                            } label: {
                                PaletteCard(
                                    palette: palette,
                                    isDark: colorScheme == .dark,
                                    isSelected: themeManager.palette == palette
                                )
                            }
                            .buttonStyle(PressableButtonStyle())
                        }
                    }
                }

                section("Appearance") {
                    Picker("Appearance", selection: $themeManager.appearance) {
                        ForEach(AppearanceMode.allCases) { mode in
                            Text(mode.title).tag(mode)
                        }
                    }
                    .pickerStyle(.segmented)
                }

                section("Gameplay") {
                    Toggle(isOn: $hapticsEnabled) {
                        Label("Haptics", systemImage: "iphone.radiowaves.left.and.right")
                            .foregroundStyle(theme.textPrimary)
                    }
                    .padding(16)
                    .card(cornerRadius: 16)
                }

                section("Progress") {
                    Button(role: .destructive) {
                        isConfirmingReset = true
                    } label: {
                        Label("Reset Progress", systemImage: "trash")
                            .font(.headline)
                            .foregroundStyle(theme.mistake)
                            .frame(maxWidth: .infinity, minHeight: 44)
                    }
                    .padding(8)
                    .card(cornerRadius: 16)
                    .confirmationDialog("Reset all progress?", isPresented: $isConfirmingReset, titleVisibility: .visible) {
                        Button("Reset Progress", role: .destructive) { model.resetProgress() }
                    } message: {
                        Text("All solved puzzles, best times and saved games will be deleted. This cannot be undone.")
                    }
                }

                section("Language") {
                    VStack(alignment: .leading, spacing: 12) {
                        Text("The game follows your device language. You can choose a different language just for this app in Settings.")
                            .font(.subheadline)
                            .foregroundStyle(theme.textSecondary)
                        Button("Change Language") {
                            if let url = URL(string: UIApplication.openSettingsURLString) { openURL(url) }
                        }
                        .buttonStyle(SecondaryButtonStyle())
                    }
                }

                if let version = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String {
                    Text("Version \(version)")
                        .font(.footnote)
                        .foregroundStyle(theme.textSecondary)
                        .frame(maxWidth: .infinity)
                }
            }
            .padding(20)
        }
        .themedScreen()
        .screenTitle("Settings")
    }

    private func section<Content: View>(_ title: LocalizedStringKey, @ViewBuilder content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(title)
                .font(.title3.bold())
                .foregroundStyle(theme.textPrimary)
            content()
        }
    }
}

/// Paletin kendi renkleriyle çizilmiş küçük bir tahta önizlemesi.
@MainActor
struct PaletteCard: View {
    let palette: ThemePalette
    let isDark: Bool
    let isSelected: Bool

    /// Minik kedi kafası
    private static let pattern = ["#...#", "##.##", "#####", "#.#.#", ".###."]

    var body: some View {
        let preview = AppTheme(palette: palette, isDark: isDark)
        VStack(spacing: 10) {
            Grid(horizontalSpacing: 3, verticalSpacing: 3) {
                ForEach(Array(Self.pattern.enumerated()), id: \.offset) { _, row in
                    GridRow {
                        ForEach(Array(row.enumerated()), id: \.offset) { _, symbol in
                            RoundedRectangle(cornerRadius: 3)
                                .fill(symbol == "#" ? preview.cellFilled : preview.surfaceMuted)
                                .frame(width: 14, height: 14)
                        }
                    }
                }
            }
            Text(palette.title)
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(preview.textPrimary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 16)
        .background(RoundedRectangle(cornerRadius: 18, style: .continuous).fill(preview.background))
        .overlay(
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .strokeBorder(isSelected ? preview.accent : preview.separator, lineWidth: isSelected ? 3 : 1)
        )
        .overlay(alignment: .topTrailing) {
            if isSelected {
                Image(systemName: "checkmark.circle.fill")
                    .foregroundStyle(preview.accent)
                    .padding(8)
            }
        }
        .accessibilityElement(children: .combine)
        .accessibilityAddTraits(isSelected ? .isSelected : [])
    }
}
