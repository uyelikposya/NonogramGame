import StoreKit
import SwiftUI
import UIKit

enum SettingsKeys {
    static let haptics = "settings.haptics"
}

@MainActor
struct SettingsView: View {
    @Environment(ThemeManager.self) private var themeManager
    @Environment(AppModel.self) private var model
    @Environment(AudioManager.self) private var audio
    @Environment(AdCoordinator.self) private var ads
    @Environment(StoreManager.self) private var store
    @Environment(\.appTheme) private var theme
    @Environment(\.colorScheme) private var colorScheme
    @Environment(\.openURL) private var openURL
    @Environment(\.requestReview) private var requestReview
    @AppStorage(SettingsKeys.haptics) private var hapticsEnabled = true
    @State private var isConfirmingReset = false
    @State private var isShowingPaywall = false
    @State private var isManagingSubscription = false

    private let paletteColumns = [GridItem(.flexible(), spacing: 12), GridItem(.flexible(), spacing: 12)]

    var body: some View {
        @Bindable var themeManager = themeManager
        @Bindable var audio = audio
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

                section("Ad-Free") {
                    VStack(alignment: .leading, spacing: 12) {
                        if store.isAdsRemoved {
                            Label("You're Ad-Free. Thank you for supporting Catgrid!", systemImage: "checkmark.seal.fill")
                                .foregroundStyle(theme.success)
                            subscriptionDetail
                            Button("Manage Subscription") { isManagingSubscription = true }
                                .buttonStyle(SecondaryButtonStyle())
                        } else {
                            Text("Remove the ads between puzzles with a monthly or yearly subscription. Optional rewarded ads for extra paws stay available.")
                                .font(.subheadline)
                                .foregroundStyle(theme.textSecondary)
                            Button {
                                isShowingPaywall = true
                            } label: {
                                Label("Go Ad-Free", systemImage: "sparkles")
                            }
                            .buttonStyle(PrimaryButtonStyle())
                            .accessibilityIdentifier("settings.adFree")
                        }
                        Button("Restore Purchases") {
                            Task { await store.restorePurchases() }
                        }
                        .buttonStyle(SecondaryButtonStyle())
                    }
                    .padding(16)
                    .card(cornerRadius: 16)
                }

                section("Sound") {
                    VStack(spacing: 18) {
                        volumeRow(
                            title: "Music",
                            icon: "music.note",
                            isOn: $audio.musicEnabled,
                            volume: $audio.musicVolume
                        )
                        Divider()
                        volumeRow(
                            title: "Sound Effects",
                            icon: "speaker.wave.2.fill",
                            isOn: $audio.effectsEnabled,
                            volume: $audio.effectsVolume,
                            preview: .fill
                        )
                    }
                    .padding(16)
                    .card(cornerRadius: 16)
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

                section("About") {
                    VStack(spacing: 0) {
                        linkRow("Rate Catgrid", icon: "star.fill") { requestReview() }
                        Divider()
                        linkRow("Support", icon: "questionmark.circle.fill") { openURL(AppLinks.support) }
                        Divider()
                        linkRow("Privacy Policy", icon: "hand.raised.fill") { openURL(AppLinks.privacyPolicy) }
                        Divider()
                        linkRow("Terms of Use", icon: "doc.text.fill") { openURL(AppLinks.termsOfUse) }
                        if ads.isPrivacyOptionsRequired {
                            Divider()
                            linkRow("Ad Privacy Choices", icon: "slider.horizontal.3") {
                                Task { await ads.presentPrivacyOptions() }
                            }
                        }
                    }
                    .padding(.horizontal, 16)
                    .card(cornerRadius: 16)
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
        .sheet(isPresented: $isShowingPaywall) {
            AdFreePaywall()
        }
        .manageSubscriptionsSheet(isPresented: $isManagingSubscription)
    }

    @ViewBuilder
    private var subscriptionDetail: some View {
        let plan: LocalizedStringKey? = switch store.activeProductID ?? "" {
        case StoreManager.yearlyProductID: "Yearly plan"
        case StoreManager.monthlyProductID: "Monthly plan"
        default: nil
        }
        if let plan {
            Text(plan)
                .font(.subheadline.bold())
                .foregroundStyle(theme.textPrimary)
        }
        if !store.willAutoRenew, let end = store.expirationDate {
            Text("Ends on \(end.formatted(date: .abbreviated, time: .omitted))")
                .font(.subheadline)
                .foregroundStyle(theme.textSecondary)
        }
    }

    private func linkRow(_ title: LocalizedStringKey, icon: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            HStack(spacing: 12) {
                Image(systemName: icon)
                    .foregroundStyle(theme.accent)
                    .frame(width: 24)
                Text(title)
                    .foregroundStyle(theme.textPrimary)
                Spacer()
                Image(systemName: "chevron.right")
                    .font(.caption.bold())
                    .foregroundStyle(theme.textSecondary)
            }
            .frame(minHeight: 48)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }

    private func volumeRow(
        title: LocalizedStringKey,
        icon: String,
        isOn: Binding<Bool>,
        volume: Binding<Double>,
        preview: SoundEffect? = nil
    ) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            Toggle(isOn: isOn) {
                Label(title, systemImage: icon)
                    .foregroundStyle(theme.textPrimary)
            }
            HStack(spacing: 12) {
                Image(systemName: "speaker.fill")
                    .font(.caption)
                    .foregroundStyle(theme.textSecondary)
                Slider(value: volume, in: 0...1) {
                    Text(title)
                } onEditingChanged: { editing in
                    // Efekt seviyesini ayarlarken örnek ses çal
                    if !editing, let preview { audio.play(preview) }
                }
                Image(systemName: "speaker.wave.3.fill")
                    .font(.caption)
                    .foregroundStyle(theme.textSecondary)
            }
            .disabled(!isOn.wrappedValue)
            .opacity(isOn.wrappedValue ? 1 : 0.4)
        }
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
