import NonogramKit
import SwiftUI

/// Genel istatistikler ve tür bazında ilerleme.
@MainActor
struct StatsView: View {
    @Environment(AppModel.self) private var model
    @Environment(\.appTheme) private var theme

    private let columns = [GridItem(.flexible(), spacing: 12), GridItem(.flexible(), spacing: 12)]

    var body: some View {
        let stats = model.progress.stats
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                LazyVGrid(columns: columns, spacing: 12) {
                    StatTile(icon: "checkmark.seal.fill", title: "Solved", value: Text(verbatim: "\(stats.solvedCount)"))
                    StatTile(icon: "cat.fill", title: "Breeds Collected", value: Text(verbatim: "\(model.collectedBreeds.count)"))
                    StatTile(icon: "crown.fill", title: "Golden Cards", value: Text(verbatim: "\(model.goldenBreeds.count)"))
                    StatTile(icon: "sparkles", title: "Perfect", value: Text(verbatim: "\(stats.perfectCount)"))
                    StatTile(icon: "star.fill", title: "Stars", value: Text(verbatim: "\(model.totalStars)"))
                    StatTile(icon: "clock.fill", title: "Total Time", value: Text(formatDuration(stats.totalSolveTime)))
                    StatTile(
                        icon: "speedometer",
                        title: "Average",
                        value: Text(stats.averageSolveTime.map(formatDuration) ?? "–")
                    )
                }

                Text("Breeds")
                    .font(.title3.bold())
                    .foregroundStyle(theme.textPrimary)

                VStack(spacing: 12) {
                    ForEach(model.catalog.chapters.filter { !$0.puzzles.isEmpty && model.progression.isUnlocked($0) }) { chapter in
                        chapterRow(chapter)
                    }
                }
            }
            .padding(20)
        }
        .themedScreen()
        .screenTitle("Statistics")
    }

    private func chapterRow(_ chapter: Chapter) -> some View {
        let records = chapter.puzzles.compactMap { model.progress.record(for: $0.id) }
        let solved = records.filter(\.isCompleted).count
        let fastest = records.compactMap(\.bestTime).min()

        return HStack(spacing: 14) {
            ChapterBadge(chapter: chapter, size: 44)
            VStack(alignment: .leading, spacing: 6) {
                HStack {
                    Text(verbatim: chapter.title.resolved)
                        .font(.headline)
                        .foregroundStyle(theme.textPrimary)
                    Spacer()
                    Text(verbatim: "\(solved)/\(chapter.puzzles.count)")
                        .font(.subheadline.monospacedDigit())
                        .foregroundStyle(theme.textSecondary)
                }
                ProgressBar(
                    value: Double(solved) / Double(chapter.puzzles.count),
                    tint: chapter.accentColor.map { Color($0) }
                )
                if let fastest {
                    Text("Fastest solve \(formatDuration(fastest))")
                        .font(.caption)
                        .foregroundStyle(theme.textSecondary)
                }
            }
        }
        .padding(16)
        .card(cornerRadius: 20)
    }
}

@MainActor
struct StatTile: View {
    @Environment(\.appTheme) private var theme
    let icon: String
    let title: LocalizedStringKey
    let value: Text

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Image(systemName: icon)
                .font(.title3)
                .foregroundStyle(theme.accent)
            value
                .font(.title2.bold().monospacedDigit())
                .foregroundStyle(theme.textPrimary)
                .minimumScaleFactor(0.7)
                .lineLimit(1)
            Text(title)
                .font(.subheadline)
                .foregroundStyle(theme.textSecondary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(16)
        .card(cornerRadius: 20)
        .accessibilityElement(children: .combine)
    }
}
