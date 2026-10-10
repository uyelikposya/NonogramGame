import NonogramKit
import SwiftUI

@MainActor
struct HomeView: View {
    @Environment(AppModel.self) private var model
    @Environment(Router.self) private var router
    @Environment(StoreManager.self) private var store
    @Environment(ReminderManager.self) private var reminders
    @Environment(\.appTheme) private var theme
    @State private var isShowingPaywall = false
    @State private var isOfferingReminder = false

    var body: some View {
        // Üstte günlük bulmaca, altında iki mod; altında kart koleksiyonu, en altta ayarlar
        ScrollView {
            VStack(spacing: 16) {
                header
                if !store.isPremium {
                    PremiumBanner { isShowingPaywall = true }
                }
                if model.todaysPuzzle != nil {
                    DailyBanner()
                }
                ModeBanner(
                    title: BadgeMode.collection.title,
                    subtitle: Text("Solve picture puzzles, collect cat cards"),
                    detail: Text("\(model.collectedBreeds.count)/\(model.breeds.count) breeds"),
                    progress: model.breeds.isEmpty ? 0 : Double(model.collectedBreeds.count) / Double(model.breeds.count),
                    colors: [Color(red: 0.98, green: 0.62, blue: 0.45), Color(red: 0.86, green: 0.36, blue: 0.48)]
                ) {
                    if let chapter = model.collectedBreeds.last ?? model.breeds.first {
                        ChapterBadge(chapter: chapter, size: 72)
                    }
                } action: {
                    router.push(.collectionHub)
                }
                .accessibilityIdentifier("home.mode.collection")

                ModeBanner(
                    title: BadgeMode.cats.title,
                    subtitle: Text("One cat per color, row and column"),
                    detail: Text("Level \(min(model.cats.solvedCount + 1, max(model.cats.levels.count, 1)))"),
                    progress: model.cats.levels.isEmpty ? 0 : Double(model.cats.solvedCount) / Double(model.cats.levels.count),
                    colors: [Color(red: 0.36, green: 0.72, blue: 0.70), Color(red: 0.45, green: 0.38, blue: 0.80)]
                ) {
                    CatGridArt()
                        .frame(width: 72, height: 72)
                } action: {
                    router.push(.catHub)
                }
                .accessibilityIdentifier("home.mode.cats")

                CollectionShelf()
                    .padding(.top, 4)

                Button {
                    router.push(.settings)
                } label: {
                    Label("Settings", systemImage: "gearshape.fill")
                }
                .buttonStyle(SecondaryButtonStyle())
                .accessibilityIdentifier("home.settings")
            }
            .padding(.horizontal, 20)
            .padding(.bottom, 16)
        }
        .scrollBounceBehavior(.basedOnSize)
        .themedScreen()
        .sheet(isPresented: $isShowingPaywall) {
            PremiumPaywall()
        }
        // Birkaç bulmacadan sonra bir kez: günlük hatırlatma ister misin?
        .task {
            guard canOfferReminder else { return }
            try? await Task.sleep(for: .seconds(0.8))
            isOfferingReminder = true
        }
        .alert("Daily reminder?", isPresented: $isOfferingReminder) {
            Button("Remind Me") {
                Task { _ = await reminders.enable() }
            }
            Button("Not Now", role: .cancel) { reminders.markAsked() }
        } message: {
            Text("We'll send one gentle reminder a day, only on days you haven't played. You can change this in Settings.")
        }
    }

    private var canOfferReminder: Bool {
        #if DEBUG
        // Ekran görüntüsü çekimini bölmesin
        if DemoContent.isEnabled { return false }
        #endif
        return reminders.shouldOffer(solvedCount: model.completedCount)
    }

    /// Uygulama simgesiyle aynı logo + oyunun adı.
    private var header: some View {
        HStack(spacing: 14) {
            Image("AppLogo")
                .resizable()
                .scaledToFit()
                .frame(width: 76, height: 76)
                .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
                .shadow(color: .black.opacity(0.12), radius: 6, y: 3)
                .accessibilityHidden(true)

            VStack(alignment: .leading, spacing: 2) {
                Text(verbatim: "Catgrid Collection")
                    .font(.title.bold())
                    .foregroundStyle(theme.textPrimary)
                    .lineLimit(1)
                    .minimumScaleFactor(0.7)
                Text(verbatim: "Nonogram")
                    .font(.headline)
                    .foregroundStyle(theme.textSecondary)
            }
            Spacer(minLength: 0)
        }
    }

}

/// Ana ekranın en üstündeki günlük bulmaca kartı: bugünün durumu ve seri.
@MainActor
struct DailyBanner: View {
    @Environment(AppModel.self) private var model
    @Environment(Router.self) private var router

    var body: some View {
        let isSolved = model.isTodaysPuzzleSolved
        let streak = model.dailyStreak
        Button {
            router.push(.daily)
        } label: {
            HStack(spacing: 14) {
                ZStack {
                    RoundedRectangle(cornerRadius: 14, style: .continuous)
                        .fill(.white.opacity(0.22))
                    VStack(spacing: 0) {
                        Text(Date(), format: .dateTime.month(.abbreviated))
                            .font(.caption2.weight(.bold))
                            .textCase(.uppercase)
                        Text(Date(), format: .dateTime.day())
                            .font(.title2.bold().monospacedDigit())
                    }
                }
                .frame(width: 56, height: 56)
                VStack(alignment: .leading, spacing: 3) {
                    Text("Daily Puzzle")
                        .font(.title3.bold())
                    Group {
                        if isSolved {
                            Text("Solved! A new one tomorrow.")
                        } else if let puzzle = model.todaysPuzzle {
                            Text("Expert · \(puzzle.columns)×\(puzzle.rows)")
                        }
                    }
                    .font(.subheadline.weight(.medium))
                    .opacity(0.9)
                }
                Spacer(minLength: 4)
                if streak > 0 {
                    Label {
                        Text(verbatim: "\(streak)")
                    } icon: {
                        Image(systemName: "flame.fill")
                    }
                    .font(.headline.monospacedDigit())
                    .padding(.horizontal, 10)
                    .padding(.vertical, 6)
                    .background(Capsule().fill(.white.opacity(0.22)))
                    .accessibilityElement()
                    .accessibilityLabel(Text("\(streak)-day streak"))
                }
                Image(systemName: isSolved ? "checkmark.circle.fill" : "chevron.right")
                    .font(isSolved ? .title3 : .footnote.weight(.bold))
            }
            .foregroundStyle(.white)
            .padding(16)
            .background(
                RoundedRectangle(cornerRadius: 24, style: .continuous)
                    .fill(LinearGradient(colors: [Color(red: 0.42, green: 0.55, blue: 0.95), Color(red: 0.55, green: 0.35, blue: 0.85)], startPoint: .topLeading, endPoint: .bottomTrailing))
            )
            .shadow(color: Color(red: 0.45, green: 0.4, blue: 0.9).opacity(0.3), radius: 10, y: 5)
        }
        .buttonStyle(PressableButtonStyle())
        .accessibilityIdentifier("home.daily")
    }
}

/// Mod kartı: renkli zemin, başlık, kısa açıklama, ilerleme ve küçük bir resim.
@MainActor
struct ModeBanner<Art: View>: View {
    let title: LocalizedStringResource
    let subtitle: Text
    let detail: Text
    let progress: Double
    let colors: [Color]
    @ViewBuilder let art: () -> Art
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 14) {
                VStack(alignment: .leading, spacing: 6) {
                    Text(title)
                        .font(.title3.bold())
                        .lineLimit(1)
                        .minimumScaleFactor(0.8)
                    subtitle
                        .font(.subheadline)
                        .opacity(0.9)
                        .fixedSize(horizontal: false, vertical: true)
                    HStack(spacing: 8) {
                        ProgressView(value: min(max(progress, 0), 1))
                            .tint(.white)
                            .background(Capsule().fill(.white.opacity(0.25)))
                        detail
                            .font(.caption.weight(.bold).monospacedDigit())
                    }
                    .padding(.top, 2)
                }
                Spacer(minLength: 0)
                art()
                Image(systemName: "chevron.right")
                    .font(.footnote.weight(.bold))
                    .opacity(0.8)
            }
            .foregroundStyle(.white)
            .padding(18)
            .frame(maxWidth: .infinity, minHeight: 120, alignment: .leading)
            .background(
                RoundedRectangle(cornerRadius: 24, style: .continuous)
                    .fill(LinearGradient(colors: colors, startPoint: .topLeading, endPoint: .bottomTrailing))
            )
            .shadow(color: colors.last?.opacity(0.3) ?? .clear, radius: 10, y: 5)
        }
        .buttonStyle(PressableButtonStyle())
    }
}

/// Bölümün vurgu renginde kedi rozeti.
@MainActor
struct ChapterBadge: View {
    @Environment(\.appTheme) private var theme
    let chapter: Chapter
    var size: CGFloat = 48

    var body: some View {
        let tint = chapter.accentColor.map { Color($0) } ?? theme.accent
        ZStack {
            Circle().fill(tint.opacity(0.3).gradient)
            if let portrait = chapter.portrait {
                // Türün piksel portresi
                ArtworkThumbnail(artwork: portrait)
                    .padding(size * 0.14)
            } else {
                Image(systemName: chapter.kind == .tutorial ? "graduationcap.fill" : "cat.fill")
                    .font(.system(size: size * 0.45))
                    .foregroundStyle(tint)
            }
        }
        .frame(width: size, height: size)
        .accessibilityHidden(true)
    }
}

