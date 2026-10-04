import NonogramKit
import SwiftUI

@MainActor
struct HomeView: View {
    @Environment(AppModel.self) private var model
    @Environment(Router.self) private var router
    @Environment(\.appTheme) private var theme

    var body: some View {
        // Tek ekrana sığacak kadar sıkı; çok küçük ekranlarda (iPhone SE) yine kaydırılabilir
        ScrollView {
            VStack(spacing: 20) {
                header
                continueCard
                CollectionShelf()
                HStack(spacing: 12) {
                    Button {
                        router.push(.chapters)
                    } label: {
                        Label("All Levels", systemImage: "square.grid.2x2")
                    }
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

