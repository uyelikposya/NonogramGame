import NonogramKit
import SwiftUI

/// 4 yıldızlık sıra: kazanılanlar altın, kalanlar soluk.
@MainActor
struct StarsView: View {
    @Environment(\.appTheme) private var theme
    let count: Int
    var size: CGFloat = 11

    var body: some View {
        HStack(spacing: size * 0.18) {
            ForEach(0..<StarRating.maximum, id: \.self) { index in
                let isEarned = index < count
                Image(systemName: isEarned ? "star.fill" : "star")
                    .font(.system(size: size, weight: .bold))
                    .foregroundStyle(isEarned ? Gold.mid : theme.textSecondary.opacity(0.35))
            }
        }
        .accessibilityElement()
        .accessibilityLabel(Text("\(count) of 4 stars"))
    }
}
