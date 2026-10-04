import NonogramKit
import SwiftUI

/// Eğitim + 15 kedi türü. Kilitli türler soluk görünür.
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
                            isUnlocked: isUnlocked
                        )
                    }
                    .buttonStyle(PressableButtonStyle())
                    .disabled(!isUnlocked)
                }
            }
            .padding(20)
        }
        .themedScreen()
        .screenTitle("Levels")
    }
}

struct ChapterCard: View {
    @Environment(\.appTheme) private var theme
    let chapter: Chapter
    let completed: Int
    let isUnlocked: Bool

    private var isComingSoon: Bool { chapter.puzzles.isEmpty }

    var body: some View {
        HStack(spacing: 16) {
            ChapterBadge(chapter: chapter, size: 56)
                .saturation(isUnlocked ? 1 : 0)

            VStack(alignment: .leading, spacing: 8) {
                Text(verbatim: chapter.title.resolved)
                    .font(.headline)
                    .foregroundStyle(theme.textPrimary)

                if isComingSoon {
                    Text("Coming soon")
                        .font(.subheadline)
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
