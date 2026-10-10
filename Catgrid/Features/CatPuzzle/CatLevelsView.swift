import NonogramKit
import SwiftUI

/// Kedi Bulmaca'nın tüm bölümleri, tahta boyutuna göre gruplu. Bölümler sırayla açılır.
@MainActor
struct CatLevelsView: View {
    @Environment(AppModel.self) private var model
    @Environment(Router.self) private var router
    @Environment(\.appTheme) private var theme

    private let columns = [GridItem(.adaptive(minimum: 58), spacing: 10)]

    var body: some View {
        let cats = model.cats
        let sizes = cats.sizes
        let unlocked = cats.unlockedSizes
        ScrollViewReader { proxy in
            ScrollView {
                LazyVStack(alignment: .leading, spacing: 18) {
                    ForEach(sizes, id: \.self) { size in
                        let levels = cats.levels.filter { $0.size == size }
                        VStack(alignment: .leading, spacing: 10) {
                            HStack {
                                if !unlocked.contains(size) {
                                    Image(systemName: "lock.fill")
                                        .foregroundStyle(theme.textSecondary)
                                }
                                Text(verbatim: "\(size)×\(size)")
                                    .font(.title3.bold())
                                    .foregroundStyle(theme.textPrimary)
                                Spacer()
                                Text(verbatim: "\(levels.filter { cats.isSolved($0) }.count)/\(levels.count)")
                                    .font(.subheadline.monospacedDigit())
                                    .foregroundStyle(theme.textSecondary)
                            }
                            if !unlocked.contains(size), let previous = sizes.last(where: { $0 < size }) {
                                Text("Solve \(CatPuzzleModel.unlockThreshold) levels of \(previous)×\(previous) to unlock.")
                                    .font(.footnote)
                                    .foregroundStyle(theme.textSecondary)
                            }
                            LazyVGrid(columns: columns, spacing: 10) {
                                ForEach(levels) { level in
                                    levelButton(level)
                                        .id(level.id)
                                }
                            }
                        }
                    }
                }
                .padding(20)
            }
            .onAppear {
                if let next = cats.nextLevel {
                    proxy.scrollTo(next.id, anchor: .center)
                }
            }
        }
        .themedScreen()
        .screenTitle("All Levels")
    }

    private func levelButton(_ level: CatLevel) -> some View {
        let cats = model.cats
        let isUnlocked = cats.isUnlocked(level)
        let result = cats.results[level.id]
        let isNext = level.id == cats.nextLevel?.id
        return Button {
            router.push(.catGame(levelID: level.id))
        } label: {
            ZStack(alignment: .topTrailing) {
                RoundedRectangle(cornerRadius: 14)
                    .fill(result != nil ? CatPalette.color(cats.number(of: level) % CatPalette.colors.count) : theme.surface)
                    .overlay {
                        RoundedRectangle(cornerRadius: 14)
                            .stroke(isNext ? theme.accent : .clear, lineWidth: 3)
                    }
                if isUnlocked {
                    Text(verbatim: "\(cats.number(of: level))")
                        .font(.headline.monospacedDigit())
                        .foregroundStyle(result != nil ? .white : theme.textPrimary)
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                } else {
                    Image(systemName: "lock.fill")
                        .font(.subheadline)
                        .foregroundStyle(theme.textSecondary.opacity(0.5))
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                }
                if result?.flawless == true {
                    Image(systemName: "crown.fill")
                        .font(.system(size: 10, weight: .bold))
                        .foregroundStyle(Gold.bright)
                        .padding(4)
                }
            }
            .frame(height: 58)
        }
        .buttonStyle(PressableButtonStyle())
        .disabled(!isUnlocked)
        .accessibilityLabel(Text("Level \(cats.number(of: level))"))
        .accessibilityValue(result != nil ? Text("Solved") : (isUnlocked ? Text(verbatim: "") : Text("Locked")))
    }
}
