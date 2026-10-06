import NonogramKit
import SwiftUI

/// Eğitim + 15 kedi türü. Kilitli türler soluk görünür.
@MainActor
struct ChaptersView: View {
    @Environment(AppModel.self) private var model
    @Environment(Router.self) private var router

    var body: some View {
        let progression = model.progression
        ScrollView {
            LazyVStack(spacing: 14) {
                ForEach(model.catalog.chapters) { chapter in
                    let isUnlocked = progression.isUnlocked(chapter)
                    Button {
                        router.push(.chapter(id: chapter.id))
                    } label: {
                        ChapterCard(
                            chapter: chapter,
                            completed: progression.completedCount(in: chapter),
                            isUnlocked: isUnlocked,
                            unlockHint: isUnlocked ? nil : unlockHint(for: chapter, progression: progression)
                        )
                    }
                    .buttonStyle(PressableButtonStyle())
                    .disabled(!isUnlocked)
                    .accessibilityIdentifier("chapter.\(chapter.id)")
                }
            }
            .padding(20)
        }
        .themedScreen()
        .screenTitle("Levels")
    }

    /// Kilitli türün altında: neyin çözülmesi gerektiği.
    private func unlockHint(for chapter: Chapter, progression: Progression) -> Text? {
        guard !chapter.puzzles.isEmpty, let previous = progression.unlockingChapter(for: chapter) else { return nil }
        let title = previous.title.resolved
        return previous.kind == .tutorial
            ? Text("Finish \(title) to unlock")
            : Text("Solve half of \(title) to unlock")
    }
}

@MainActor
struct ChapterCard: View {
    @Environment(\.appTheme) private var theme
    let chapter: Chapter
    let completed: Int
    let isUnlocked: Bool
    var unlockHint: Text?

    private var isComingSoon: Bool { chapter.puzzles.isEmpty }

    var body: some View {
        HStack(spacing: 16) {
            ChapterBadge(chapter: chapter, size: 56)
                .saturation(isUnlocked ? 1 : 0)

            VStack(alignment: .leading, spacing: 8) {
                Text(verbatim: chapter.title.resolved)
                    .font(.headline)
                    .foregroundStyle(theme.textPrimary)
                if let subtitle = chapter.subtitle {
                    Text(verbatim: subtitle.resolved)
                        .font(.caption)
                        .foregroundStyle(theme.textSecondary)
                }

                if isComingSoon {
                    Text("Coming soon")
                        .font(.subheadline)
                        .foregroundStyle(theme.textSecondary)
                } else if let unlockHint {
                    Label { unlockHint } icon: { Image(systemName: "lock.fill") }
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(theme.textSecondary)
                } else {
                    HStack(spacing: 10) {
                        ProgressBar(
                            value: Double(completed) / Double(max(chapter.puzzles.count, 1)),
                            tint: chapter.accentColor.map { Color($0) }
                        )
                        Text(verbatim: "\(completed)/\(chapter.puzzles.count)")
                            .font(.caption.monospacedDigit())
                            .foregroundStyle(theme.textSecondary)
                    }
                }
            }

            Spacer(minLength: 0)

            Image(systemName: isUnlocked ? "chevron.right" : "lock.fill")
                .font(.body.weight(.semibold))
                .foregroundStyle(theme.textSecondary)
        }
        .padding(16)
        .card(cornerRadius: 20)
        .opacity(isUnlocked ? 1 : 0.6)
        .accessibilityElement(children: .combine)
        .accessibilityValue(isUnlocked ? Text(verbatim: "") : Text("Locked"))
    }
}
