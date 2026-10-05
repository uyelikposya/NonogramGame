import NonogramKit
import SwiftUI

/// Kazanılan kedi kartları. Toplam tür sayısı bilerek gösterilmez; yeni türler geldikçe koleksiyon büyür.
@MainActor
struct CollectionView: View {
    @Environment(AppModel.self) private var model
    @Environment(\.appTheme) private var theme
    @State private var selected: CardSelection?

    private let columns = [GridItem(.adaptive(minimum: 150), spacing: 14)]

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                CollectionSummary()

                LazyVGrid(columns: columns, spacing: 14) {
                    ForEach(model.collectedCards) { selection in
                        if let card = selection.chapter.card {
                            Button {
                                selected = selection
                            } label: {
                                BreedCardView(chapter: selection.chapter, card: card, style: .compact, isGolden: selection.isGolden)
                            }
                            .buttonStyle(PressableButtonStyle())
                        }
                    }
                    if model.hasUnmetBreeds {
                        MysteryCardView()
                    }
                }
            }
            .padding(20)
        }
        .themedScreen()
        .screenTitle("Card Collection")
        .sheet(item: $selected) { selection in
            CardDetailSheet(chapter: selection.chapter, isGolden: selection.isGolden)
        }
    }
}

/// "3 kedi türü topladın. Hâlâ tanışmadığın kediler var!"
@MainActor
struct CollectionSummary: View {
    @Environment(AppModel.self) private var model
    @Environment(\.appTheme) private var theme

    var body: some View {
        let count = model.collectedBreeds.count
        Group {
            if count == 0 {
                Text("Finish all puzzles of a breed to win its card.")
            } else if model.hasUnmetBreeds {
                Text("You've collected \(count) cat breeds. There are still cats you haven't met!")
            } else {
                Text("You've met every cat. New breeds are on their way!")
            }
        }
        .font(.subheadline)
        .foregroundStyle(theme.textSecondary)
    }
}

/// Kartın tam hali (koleksiyondan dokununca).
@MainActor
struct CardDetailSheet: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.appTheme) private var theme
    let chapter: Chapter
    var isNewCard = false
    var isGolden = false

    var body: some View {
        ScrollView {
            VStack(spacing: 20) {
                if isNewCard {
                    VStack(spacing: 6) {
                        Image(systemName: isGolden ? "crown.fill" : "sparkles")
                            .font(.largeTitle)
                            .foregroundStyle(isGolden ? AnyShapeStyle(Gold.foil) : AnyShapeStyle(theme.accent))
                        Text(isGolden ? LocalizedStringKey("Golden Card unlocked!") : LocalizedStringKey("New card unlocked!"))
                            .font(.title2.bold())
                            .foregroundStyle(theme.textPrimary)
                        Text(isGolden
                             ? LocalizedStringKey("You solved every golden \(chapter.title.resolved) puzzle.")
                             : LocalizedStringKey("You solved every \(chapter.title.resolved) puzzle."))
                            .font(.subheadline)
                            .multilineTextAlignment(.center)
                            .foregroundStyle(theme.textSecondary)
                    }
                    .padding(.top, 8)
                }
                if let card = chapter.card {
                    FlippableBreedCard(chapter: chapter, card: card, isGolden: isGolden)
                        .frame(maxWidth: 360)
                    Label("Tap the card to flip it", systemImage: "hand.tap.fill")
                        .font(.footnote)
                        .foregroundStyle(theme.textSecondary)
                }
                Button(isNewCard ? "Add to Collection" : "Close") { dismiss() }
                    .buttonStyle(PrimaryButtonStyle())
                    .frame(maxWidth: 360)
            }
            .padding(24)
            .frame(maxWidth: .infinity)
        }
        .background(theme.background.ignoresSafeArea())
        .appChrome()
        .presentationDragIndicator(.visible)
    }
}

/// Ana sayfadaki yatay kart şeridi.
@MainActor
struct CollectionShelf: View {
    @Environment(AppModel.self) private var model
    @Environment(Router.self) private var router
    @Environment(\.appTheme) private var theme

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text("Card Collection")
                    .font(.title3.bold())
                    .foregroundStyle(theme.textPrimary)
                Spacer()
                Button("See All") { router.push(.collection) }
                    .font(.subheadline.bold())
            }
            CollectionSummary()
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 12) {
                    ForEach(model.collectedCards.reversed()) { selection in
                        if let card = selection.chapter.card {
                            Button {
                                router.push(.collection)
                            } label: {
                                BreedCardView(chapter: selection.chapter, card: card, style: .compact, isGolden: selection.isGolden)
                                    .frame(width: 104)
                            }
                            .buttonStyle(PressableButtonStyle())
                        }
                    }
                    if model.hasUnmetBreeds {
                        MysteryCardView()
                            .frame(width: 104)
                    }
                }
                .padding(.vertical, 6)
                .padding(.horizontal, 2)
            }
        }
    }
}
