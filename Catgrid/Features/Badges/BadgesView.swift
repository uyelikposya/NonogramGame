import SwiftUI

/// Rozetler: kazanılanlar renkli ve tarihli, kalanlar soluk ve nasıl kazanılacağıyla.
@MainActor
struct BadgesView: View {
    @Environment(AppModel.self) private var model
    @Environment(\.appTheme) private var theme

    private let columns = [GridItem(.flexible(), spacing: 12), GridItem(.flexible(), spacing: 12)]

    var body: some View {
        let badges = model.badges
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                Text(verbatim: "\(badges.earned.count)/\(Badge.allCases.count)")
                    .font(.title2.bold().monospacedDigit())
                    .foregroundStyle(theme.textPrimary)
                LazyVGrid(columns: columns, spacing: 12) {
                    ForEach(Badge.allCases) { badge in
                        BadgeTile(badge: badge, earnedAt: badges.earned[badge])
                    }
                }
            }
            .padding(20)
        }
        .themedScreen()
        .screenTitle("Badges")
    }
}

@MainActor
struct BadgeTile: View {
    @Environment(\.appTheme) private var theme
    let badge: Badge
    let earnedAt: Date?

    var body: some View {
        let isEarned = earnedAt != nil
        VStack(spacing: 8) {
            ZStack {
                Circle()
                    .fill(isEarned ? AnyShapeStyle(Gold.foil) : AnyShapeStyle(theme.surfaceMuted))
                Image(systemName: isEarned ? badge.icon : "lock.fill")
                    .font(.title2.weight(.bold))
                    .foregroundStyle(isEarned ? Gold.ink : theme.textSecondary.opacity(0.6))
            }
            .frame(width: 56, height: 56)
            Text(badge.title)
                .font(.subheadline.bold())
                .multilineTextAlignment(.center)
                .foregroundStyle(isEarned ? theme.textPrimary : theme.textSecondary)
            Text(badge.detail)
                .font(.caption)
                .multilineTextAlignment(.center)
                .foregroundStyle(theme.textSecondary)
                .fixedSize(horizontal: false, vertical: true)
            if let earnedAt {
                Text(earnedAt, format: .dateTime.day().month().year())
                    .font(.caption2)
                    .foregroundStyle(Gold.deep)
            }
        }
        .frame(maxWidth: .infinity, minHeight: 170, alignment: .top)
        .padding(12)
        .card(cornerRadius: 18)
        .opacity(isEarned ? 1 : 0.75)
        .accessibilityElement(children: .combine)
    }
}
