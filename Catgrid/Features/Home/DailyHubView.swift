import NonogramKit
import SwiftUI

/// Günlük bulmaca: bugün ve önceki 10 gün. Kaçırılan günler sonradan çözülebilir.
@MainActor
struct DailyHubView: View {
    @Environment(AppModel.self) private var model
    @Environment(Router.self) private var router
    @Environment(\.appTheme) private var theme
    @State private var selected: DayKey?

    private let columns = [GridItem(.flexible(), spacing: 12), GridItem(.flexible(), spacing: 12)]

    var body: some View {
        let days = model.recentDays
        let day = selected ?? days.first ?? model.today
        let mode = BadgeMode.daily
        let badgeCount = Badge.all(in: mode).filter { model.badges.isEarned($0) }.count
        let solvedRecent = days.filter { model.isDailySolved($0) }.count
        ScrollView {
            VStack(spacing: 16) {
                HubHero(
                    title: mode.title,
                    subtitle: Text("\(model.dailyStreak)-day streak"),
                    progress: Double(solvedRecent) / Double(max(days.count, 1)),
                    colors: [Color(red: 0.42, green: 0.55, blue: 0.95), Color(red: 0.55, green: 0.35, blue: 0.85)]
                ) {
                    ZStack {
                        Circle().fill(.white.opacity(0.2))
                        Image(systemName: "flame.fill")
                            .font(.system(size: 44))
                            .foregroundStyle(.white)
                    }
                }

                dayStrip(days, selected: day)

                selectedDayCard(day)

                LazyVGrid(columns: columns, spacing: 12) {
                    StatTile(icon: "flame.fill", title: "Streak", value: Text(verbatim: "\(model.dailyStreak)"))
                    StatTile(icon: "checkmark.seal.fill", title: "Solved", value: Text(verbatim: "\(model.badgeProgress.dailySolved)"))
                }

                HubRow(
                    icon: "medal.fill",
                    title: "My Badges",
                    detail: Text(verbatim: "\(badgeCount)/\(Badge.all(in: mode).count)"),
                    tint: Gold.deep
                ) { router.push(.badges(mode)) }
            }
            .padding(20)
        }
        .themedScreen()
        .screenTitle(mode.title)
    }

    private func dayStrip(_ days: [DayKey], selected: DayKey) -> some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 10) {
                // Eskiden yeniye: bugün en sağda
                ForEach(Array(days.reversed()), id: \.dayNumber) { day in
                    let isSelected = day == selected
                    let isSolved = model.isDailySolved(day)
                    Button {
                        withAnimation(.snappy) { self.selected = day }
                    } label: {
                        VStack(spacing: 4) {
                            Text(day.date, format: .dateTime.weekday(.abbreviated))
                                .font(.caption2.weight(.semibold))
                            Text(day.date, format: .dateTime.day())
                                .font(.title3.bold().monospacedDigit())
                            Image(systemName: isSolved ? "checkmark.circle.fill" : (day == model.today ? "star.fill" : "circle"))
                                .font(.caption)
                                .foregroundStyle(isSelected ? theme.onAccent : (isSolved ? theme.success : theme.textSecondary.opacity(0.5)))
                        }
                        .foregroundStyle(isSelected ? theme.onAccent : theme.textPrimary)
                        .frame(width: 54, height: 78)
                        .background(
                            RoundedRectangle(cornerRadius: 16, style: .continuous)
                                .fill(isSelected ? theme.accent : theme.surface)
                        )
                    }
                    .buttonStyle(PressableButtonStyle())
                    .id(day.dayNumber)
                    .accessibilityLabel(Text(day.date, format: .dateTime.weekday(.wide).day().month(.wide)))
                    .accessibilityValue(isSolved ? Text("Solved") : Text(verbatim: ""))
                }
            }
            .padding(.vertical, 4)
        }
        .defaultScrollAnchor(.trailing)
    }

    private func selectedDayCard(_ day: DayKey) -> some View {
        let puzzle = model.daily.puzzle(for: day)
        let isSolved = model.isDailySolved(day)
        let isResuming = model.progress.hasSavedGame(for: day.puzzleID)
        return VStack(alignment: .leading, spacing: 14) {
            HStack(spacing: 14) {
                ZStack {
                    RoundedRectangle(cornerRadius: 14).fill(theme.surfaceMuted)
                    if isSolved, let puzzle {
                        ArtworkThumbnail(artwork: puzzle.artwork)
                            .padding(6)
                    } else {
                        Image(systemName: "calendar")
                            .font(.title2)
                            .foregroundStyle(theme.accent)
                    }
                }
                .frame(width: 64, height: 64)
                VStack(alignment: .leading, spacing: 4) {
                    Group {
                        if day == model.today {
                            Text("Today")
                        } else {
                            Text(day.date, format: .dateTime.weekday(.wide))
                        }
                    }
                    .font(.headline)
                        .foregroundStyle(theme.textPrimary)
                    Text(day.date, format: .dateTime.day().month(.wide).year())
                        .font(.subheadline)
                        .foregroundStyle(theme.textSecondary)
                    if let puzzle {
                        Text("Expert · \(puzzle.columns)×\(puzzle.rows)")
                            .font(.caption.weight(.semibold))
                            .foregroundStyle(theme.textSecondary)
                    }
                }
                Spacer()
                if isSolved {
                    Image(systemName: "checkmark.seal.fill")
                        .font(.title2)
                        .foregroundStyle(theme.success)
                }
            }
            Button {
                router.push(.game(puzzleID: day.puzzleID))
            } label: {
                Label(
                    isSolved ? "Play Again" : (isResuming ? "Resume" : "Play"),
                    systemImage: isSolved ? "arrow.counterclockwise" : (isResuming ? "arrow.clockwise" : "play.fill")
                )
            }
            .buttonStyle(PrimaryButtonStyle())
            .disabled(puzzle == nil)
            .accessibilityIdentifier("daily.play")
            if day != model.today, !isSolved {
                Text("Missed a day? You can solve the puzzles of the last 10 days.")
                    .font(.footnote)
                    .foregroundStyle(theme.textSecondary)
            }
        }
        .padding(16)
        .card()
    }
}
