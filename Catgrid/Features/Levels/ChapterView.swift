import NonogramKit
import SwiftUI

/// Bir türün 30 bulmacası: çözülenler küçük resim olarak, sıradaki vurgulu, gerisi kilitli.
@MainActor
struct ChapterView: View {
    @Environment(AppModel.self) private var model
    @Environment(Router.self) private var router
    @Environment(\.appTheme) private var theme
    let chapterID: String

    private let columns = [GridItem(.adaptive(minimum: 72), spacing: 12)]

    var body: some View {
        if let chapter = model.chapter(withID: chapterID) {
            let progression = model.progression
            ScrollView {
                VStack(spacing: 20) {
                    HStack(spacing: 14) {
                        ChapterBadge(chapter: chapter, size: 56)
                        VStack(alignment: .leading, spacing: 6) {
                            if let subtitle = chapter.subtitle {
                                Text(verbatim: subtitle.resolved)
                                    .font(.headline)
                                    .foregroundStyle(theme.textPrimary)
                            }
                            Text("\(progression.completedCount(in: chapter)) of \(chapter.puzzles.count) solved")
                                .font(.subheadline)
                                .foregroundStyle(theme.textSecondary)
                            ProgressBar(
                                value: Double(progression.completedCount(in: chapter)) / Double(max(chapter.puzzles.count, 1)),
                                tint: chapter.accentColor.map { Color($0) }
                            )
                        }
                    }

                    LazyVGrid(columns: columns, spacing: 12) {
                        ForEach(Array(chapter.puzzles.enumerated()), id: \.element.id) { offset, puzzle in
                            let state = PuzzleTile.TileState(
                                isCompleted: progression.isCompleted(puzzle.id),
                                isUnlocked: progression.isUnlocked(puzzle.id)
                            )
                            Button {
                                router.push(.game(puzzleID: puzzle.id))
                            } label: {
                                PuzzleTile(
                                    puzzle: puzzle,
                                    number: offset + 1,
                                    state: state,
                                    isInProgress: model.progress.hasSavedGame(for: puzzle.id)
                                )
                            }
                            .buttonStyle(PressableButtonStyle())
                            .disabled(state == .locked)
                        }
                    }
                }
                .padding(20)
            }
            .themedScreen()
            .screenTitle(verbatim: chapter.title.resolved)
        } else {
            ContentUnavailableView("Chapter not found", systemImage: "questionmark.circle")
                .themedScreen()
        }
    }
}

@MainActor
struct PuzzleTile: View {
    enum TileState: Equatable {
        case locked
        case playable
        case completed

        init(isCompleted: Bool, isUnlocked: Bool) {
            self = isCompleted ? .completed : (isUnlocked ? .playable : .locked)
        }
    }

    @Environment(\.appTheme) private var theme
    let puzzle: Puzzle
    let number: Int
    let state: TileState
    /// Yarım bırakılmış: köşede küçük bir rozet gösterilir.
    var isInProgress = false

    var body: some View {
        let shape = RoundedRectangle(cornerRadius: 16, style: .continuous)
        ZStack {
            switch state {
            case .completed:
                ArtworkThumbnail(artwork: puzzle.artwork)
                    .padding(10)
            case .playable:
                Text(verbatim: "\(number)")
                    .font(.title2.bold())
                    .foregroundStyle(theme.onAccent)
            case .locked:
                Image(systemName: "lock.fill")
                    .foregroundStyle(theme.textSecondary.opacity(0.6))
            }
        }
        .frame(maxWidth: .infinity)
        .aspectRatio(1, contentMode: .fit)
        .background(shape.fill(state == .playable ? theme.accent : (state == .completed ? theme.surfaceMuted : theme.surface)))
        .overlay(shape.strokeBorder(theme.separator, lineWidth: state == .locked ? 1 : 0))
        .overlay(alignment: .topTrailing) {
            if isInProgress && state != .locked {
                Image(systemName: "hourglass.circle.fill")
                    .font(.body)
                    .symbolRenderingMode(.palette)
                    .foregroundStyle(theme.onAccent, theme.textPrimary)
                    .offset(x: 4, y: -4)
            }
        }
        .shadow(color: state == .locked ? .clear : theme.cardShadow, radius: 6, y: 2)
        .accessibilityElement()
        .accessibilityLabel(accessibilityText)
    }

    private var accessibilityText: Text {
        switch state {
        case .completed: Text("Puzzle \(number), solved: \(puzzle.title.resolved)")
        case .playable: isInProgress ? Text("Puzzle \(number), in progress") : Text("Puzzle \(number)")
        case .locked: Text("Puzzle \(number), locked")
        }
    }
}
