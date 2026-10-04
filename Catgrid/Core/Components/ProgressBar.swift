import SwiftUI

@MainActor
struct ProgressBar: View {
    @Environment(\.appTheme) private var theme
    let value: Double
    var tint: Color?

    var body: some View {
        GeometryReader { proxy in
            Capsule()
                .fill(theme.surfaceMuted)
                .overlay(alignment: .leading) {
                    Capsule()
                        .fill(tint ?? theme.accent)
                        .frame(width: proxy.size.width * min(max(value, 0), 1))
                }
        }
        .frame(height: 8)
        .accessibilityElement()
        .accessibilityValue(Text(value, format: .percent.precision(.fractionLength(0))))
    }
}
