import NonogramKit
import SwiftUI

@MainActor
struct HomeView: View {
    @Environment(AppModel.self) private var model
    @Environment(Router.self) private var router
    @Environment(\.appTheme) private var theme

    var body: some View {
        ScrollView {
            VStack(spacing: 28) {
                header
                continueCard
                Button {
                    router.push(.chapters)
                } label: {
                    Label("All Levels", systemImage: "square.grid.2x2")
                }
                .buttonStyle(SecondaryButtonStyle())
            }
            .padding(20)
        }
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

    private var header: some View {
        VStack(spacing: 12) {
            Image(systemName: "cat.fill")
                .font(.system(size: 56))
                .foregroundStyle(theme.accent)
                .frame(width: 112, height: 112)
                .background(Circle().fill(theme.surfaceMuted))
                .accessibilityHidden(true)

            Text(verbatim: "Purrfect Nonogram")
                .font(.largeTitle.bold())
                .foregroundStyle(theme.textPrimary)

            VStack(spacing: 6) {
                Text("\(model.completedCount) of \(model.plannedPuzzleCount) puzzles solved")
                    .font(.subheadline)
                    .foregroundStyle(theme.textSecondary)
                ProgressBar(value: Double(model.completedCount) / Double(max(model.plannedPuzzleCount, 1)))
                    .frame(maxWidth: 220)
            }
        }
        .padding(.top, 12)
    }

    @ViewBuilder
    private var continueCard: some View {
        if let puzzle = model.progression.nextPlayable,
           let chapter = model.catalog.chapter(containing: puzzle.id) {
            VStack(alignment: .leading, spacing: 16) {
                HStack(spacing: 14) {
                    ChapterBadge(chapter: chapter, size: 52)
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
                    let title: LocalizedStringKey = model.completedCount == 0 ? "Start Playing" : "Continue"
                    Label(title, systemImage: "play.fill")
                }
                .buttonStyle(PrimaryButtonStyle())
            }
            .padding(20)
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
        Image(systemName: chapter.kind == .tutorial ? "graduationcap.fill" : "cat.fill")
            .font(.system(size: size * 0.45))
            .foregroundStyle(.white)
            .frame(width: size, height: size)
            .background(Circle().fill(tint.gradient))
            .accessibilityHidden(true)
    }
}
