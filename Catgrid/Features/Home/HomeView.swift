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
        // Tek ekrana sığacak kadar sıkı; çok küçük ekranlarda (iPhone SE) yine kaydırılabilir
        ScrollView {
            VStack(spacing: 18) {
                header
                if !store.isPremium {
                    PremiumBanner { isShowingPaywall = true }
                }
                continueCard
                if model.todaysPuzzle != nil {
                    DailyCard()
                }
                CollectionShelf()
                HStack(spacing: 12) {
                    Button {
                        router.push(.chapters)
                    } label: {
                        Label("All Levels", systemImage: "square.grid.2x2")
                    }
                    .accessibilityIdentifier("home.levels")
                    Button {
                        router.push(.stats)
                    } label: {
                        Label("Statistics", systemImage: "chart.bar.fill")
                    }
                }
                .buttonStyle(SecondaryButtonStyle())
            }
            .padding(.horizontal, 20)
            .padding(.bottom, 12)
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
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button {
                    router.push(.settings)
                } label: {
                    Image(systemName: "gearshape")
                        .foregroundStyle(theme.textPrimary)
                }
                .accessibilityLabel(Text("Settings"))
            }
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

    @ViewBuilder
    private var continueCard: some View {
        if let puzzle = model.resumablePuzzle,
           let chapter = model.catalog.chapter(containing: puzzle.id) {
            VStack(alignment: .leading, spacing: 14) {
                HStack(spacing: 14) {
                    ChapterBadge(chapter: chapter, size: 48)
                    VStack(alignment: .leading, spacing: 4) {
                        Text(verbatim: chapter.title.resolved)
                            .font(.headline)
                            .foregroundStyle(theme.textPrimary)
                        Text("Puzzle \(model.number(of: puzzle)) · \(puzzle.columns)×\(puzzle.rows)")
                            .font(.subheadline)
                            .foregroundStyle(theme.textSecondary)
                    }
                    Spacer()
                }
                Button {
                    router.push(.game(puzzleID: puzzle.id))
                } label: {
                    let isResuming = model.progress.hasSavedGame(for: puzzle.id)
                    let title: LocalizedStringKey = isResuming
                        ? "Resume"
                        : (model.completedCount == 0 ? "Start Playing" : "Continue")
                    Label(title, systemImage: isResuming ? "arrow.clockwise" : "play.fill")
                }
                .buttonStyle(PrimaryButtonStyle())
                .accessibilityIdentifier("home.continue")
            }
            .padding(16)
            .card()
        } else {
            VStack(spacing: 8) {
                Image(systemName: "trophy.fill")
                    .font(.largeTitle)
                    .foregroundStyle(theme.success)
                Text("You solved every puzzle!")
                    .font(.headline)
                    .foregroundStyle(theme.textPrimary)
                Text("New breeds are on their way.")
                    .font(.subheadline)
                    .foregroundStyle(theme.textSecondary)
            }
            .frame(maxWidth: .infinity)
            .padding(24)
            .card()
        }
    }
}

/// Ana ekranda günün bulmacası ve seri.
@MainActor
struct DailyCard: View {
    @Environment(AppModel.self) private var model
    @Environment(Router.self) private var router
    @Environment(\.appTheme) private var theme

    var body: some View {
        let isSolved = model.isTodaysPuzzleSolved
        let streak = model.dailyStreak
        Button {
            router.push(.daily)
        } label: {
            HStack(spacing: 14) {
                ZStack {
                    Circle().fill(theme.accent.opacity(0.18).gradient)
                    Image(systemName: isSolved ? "checkmark.seal.fill" : "calendar")
                        .font(.title2)
                        .foregroundStyle(isSolved ? theme.success : theme.accent)
                }
                .frame(width: 48, height: 48)
                VStack(alignment: .leading, spacing: 4) {
                    Text("Daily Puzzle")
                        .font(.headline)
                        .foregroundStyle(theme.textPrimary)
                    Group {
                        if isSolved {
                            Text("Solved! A new one tomorrow.")
                        } else if let puzzle = model.todaysPuzzle {
                            Text("Expert · \(puzzle.columns)×\(puzzle.rows)")
                        }
                    }
                    .font(.subheadline)
                    .foregroundStyle(theme.textSecondary)
                }
                Spacer(minLength: 4)
                if streak > 0 {
                    Label {
                        Text(verbatim: "\(streak)")
                    } icon: {
                        Image(systemName: "flame.fill")
                    }
                    .font(.headline.monospacedDigit())
                    .foregroundStyle(theme.accent)
                    .accessibilityElement()
                    .accessibilityLabel(Text("\(streak)-day streak"))
                }
                Image(systemName: "chevron.right")
                    .font(.footnote.weight(.bold))
                    .foregroundStyle(theme.textSecondary)
            }
            .padding(16)
            .card()
        }
        .buttonStyle(PressableButtonStyle())
        .accessibilityIdentifier("home.daily")
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

