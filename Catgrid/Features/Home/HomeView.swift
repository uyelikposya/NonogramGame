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

            VStack(spacing: 2) {
                Text(verbatim: "Catgrid Collection")
                    .font(.largeTitle.bold())
                    .foregroundStyle(theme.textPrimary)
                Text(verbatim: "Nonogram")
                    .font(.headline)
                    .foregroundStyle(theme.textSecondary)
            }

            CollectionStrip()
        }
        .padding(.top, 12)
    }

    @ViewBuilder
    private var continueCard: some View {
        if let puzzle = model.resumablePuzzle,
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
                    let isResuming = model.progress.hasSavedGame(for: puzzle.id)
                    let title: LocalizedStringKey = isResuming
                        ? "Resume"
                        : (model.completedCount == 0 ? "Start Playing" : "Continue")
                    Label(title, systemImage: isResuming ? "arrow.clockwise" : "play.fill")
                }
                .buttonStyle(PrimaryButtonStyle())
                .accessibilityIdentifier("home.continue")
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

/// Toplanan kedi türleri. Toplam tür sayısı bilerek gösterilmez: yeni türler geldikçe
/// koleksiyon büyür, oyuncuya "henüz tanışmadığın kediler var" denir.
@MainActor
struct CollectionStrip: View {
    @Environment(AppModel.self) private var model
    @Environment(\.appTheme) private var theme

    var body: some View {
        let collected = model.collectedBreeds
        VStack(spacing: 10) {
            Group {
                if collected.isEmpty {
                    Text("Finish a breed's puzzles to add your first cat to the collection.")
                } else if model.hasUnmetBreeds {
                    Text("You've collected \(collected.count) cat breeds. There are still cats you haven't met!")
                } else {
                    Text("You've met every cat. New breeds are on their way!")
                }
            }
            .font(.subheadline)
            .multilineTextAlignment(.center)
            .foregroundStyle(theme.textSecondary)

            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 8) {
                    ForEach(collected) { chapter in
                        ChapterBadge(chapter: chapter, size: 40)
                            .accessibilityLabel(Text(verbatim: chapter.title.resolved))
                    }
                    if model.hasUnmetBreeds {
                        Image(systemName: "questionmark")
                            .font(.headline)
                            .foregroundStyle(theme.textSecondary)
                            .frame(width: 40, height: 40)
                            .background(Circle().strokeBorder(theme.separator, style: StrokeStyle(lineWidth: 2, dash: [4, 3])))
                            .accessibilityLabel(Text("Unmet cats"))
                    }
                }
                .padding(.horizontal, 4)
            }
            .fixedSize(horizontal: false, vertical: true)
        }
        .padding(16)
        .frame(maxWidth: .infinity)
        .card(cornerRadius: 20)
    }
}
