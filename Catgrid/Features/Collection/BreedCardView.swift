import NonogramKit
import SwiftUI
import UIKit

extension BreedCard.Rarity {
    var title: LocalizedStringResource {
        switch self {
        case .common: "Common"
        case .rare: "Rare"
        case .epic: "Epic"
        case .legendary: "Legendary"
        }
    }

    var stars: Int {
        switch self {
        case .common: 1
        case .rare: 2
        case .epic: 3
        case .legendary: 4
        }
    }

    /// Çerçeve renkleri: gümüş, mavi, mor, altın.
    var frameColors: [Color] {
        switch self {
        case .common: [Color(hex: "#C9CED6"), Color(hex: "#8E96A3"), Color(hex: "#E4E8EE")]
        case .rare: [Color(hex: "#7FB2F0"), Color(hex: "#3D6FD1"), Color(hex: "#A9D0FF")]
        case .epic: [Color(hex: "#C79BF2"), Color(hex: "#7A3FCF"), Color(hex: "#E2C6FF")]
        case .legendary: [Color(hex: "#F7D774"), Color(hex: "#D18B1F"), Color(hex: "#FFF1B8")]
        }
    }
}

/// Pokemon kartı tarzında kedi türü kartı.
@MainActor
struct BreedCardView: View {
    enum Style {
        /// Koleksiyon ızgarası ve ana sayfa şeridi için küçük kart.
        case compact
        /// Tüm bilgilerin göründüğü kart.
        case full
    }

    @Environment(\.appTheme) private var theme
    let chapter: Chapter
    let card: BreedCard
    var style: Style = .full

    private var accent: Color { chapter.accentColor.map { Color($0) } ?? theme.accent }
    private var isCompact: Bool { style == .compact }

    var body: some View {
        VStack(alignment: .leading, spacing: isCompact ? 6 : 12) {
            header
            artwork
            if !isCompact {
                details
                statsView
                Text(verbatim: card.fact.resolved)
                    .font(.footnote.italic())
                    .foregroundStyle(theme.textPrimary)
                    .fixedSize(horizontal: false, vertical: true)
                    .padding(10)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(RoundedRectangle(cornerRadius: 10).fill(theme.surfaceMuted))
            }
        }
        .padding(isCompact ? 8 : 16)
        .background(
            RoundedRectangle(cornerRadius: isCompact ? 14 : 24, style: .continuous)
                .fill(LinearGradient(colors: [accent.opacity(0.35), theme.surface], startPoint: .top, endPoint: .bottom))
        )
        .overlay(
            RoundedRectangle(cornerRadius: isCompact ? 14 : 24, style: .continuous)
                .strokeBorder(
                    LinearGradient(colors: card.rarity.frameColors, startPoint: .topLeading, endPoint: .bottomTrailing),
                    lineWidth: isCompact ? 3 : 6
                )
        )
        .shadow(color: card.rarity.frameColors[1].opacity(0.35), radius: isCompact ? 4 : 12, y: 4)
        .accessibilityElement(children: .combine)
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: 2) {
            HStack(alignment: .firstTextBaseline) {
                Text(verbatim: chapter.title.resolved)
                    .font(isCompact ? .caption.bold() : .title3.bold())
                    .foregroundStyle(theme.textPrimary)
                    .lineLimit(1)
                    .minimumScaleFactor(0.7)
                Spacer(minLength: 4)
                Text(verbatim: String(format: "#%02d", card.number))
                    .font((isCompact ? Font.caption2 : Font.subheadline).monospacedDigit().bold())
                    .foregroundStyle(theme.textSecondary)
            }
            HStack(spacing: 2) {
                ForEach(0..<card.rarity.stars, id: \.self) { _ in
                    Image(systemName: "star.fill")
                }
                if !isCompact {
                    Text(card.rarity.title)
                        .padding(.leading, 4)
                }
            }
            .font(isCompact ? .system(size: 8) : .caption.bold())
            .foregroundStyle(card.rarity.frameColors[1])
        }
    }

    /// Assets'te "card-<tür>" adlı (lisanslı) bir fotoğraf varsa o, yoksa piksel portre.
    @ViewBuilder
    private var artwork: some View {
        ZStack {
            RoundedRectangle(cornerRadius: isCompact ? 10 : 16)
                .fill(LinearGradient(colors: [accent.opacity(0.55), accent.opacity(0.15)], startPoint: .top, endPoint: .bottom))
            if let photo = UIImage(named: "card-\(chapter.id)") {
                Image(uiImage: photo)
                    .resizable()
                    .scaledToFill()
                    .clipShape(RoundedRectangle(cornerRadius: isCompact ? 10 : 16))
            } else if let portrait = chapter.portrait {
                ArtworkThumbnail(artwork: portrait)
                    .padding(isCompact ? 8 : 18)
            }
        }
        .aspectRatio(isCompact ? 1 : 1.35, contentMode: .fit)
        .clipped()
    }

    private var details: some View {
        VStack(alignment: .leading, spacing: 6) {
            detailRow(icon: "globe.europe.africa.fill", label: "Origin", value: Text(verbatim: card.origin.resolved))
            detailRow(icon: "hourglass", label: "Lifespan", value: Text("\(card.lifespan) years"))
            detailRow(icon: "paintbrush.pointed.fill", label: "Coat", value: Text(verbatim: card.coat.resolved))
        }
        .font(.subheadline)
    }

    private func detailRow(icon: String, label: LocalizedStringKey, value: Text) -> some View {
        HStack(alignment: .firstTextBaseline, spacing: 8) {
            Image(systemName: icon)
                .foregroundStyle(accent)
                .frame(width: 20)
            Text(label)
                .foregroundStyle(theme.textSecondary)
            Spacer(minLength: 8)
            value
                .foregroundStyle(theme.textPrimary)
                .multilineTextAlignment(.trailing)
        }
    }

    private var statsView: some View {
        VStack(spacing: 6) {
            statRow("Energy", card.stats.energy)
            statRow("Affection", card.stats.affection)
            statRow("Playfulness", card.stats.playfulness)
            statRow("Grooming", card.stats.grooming)
        }
        .padding(10)
        .background(RoundedRectangle(cornerRadius: 10).fill(theme.surfaceMuted.opacity(0.6)))
    }

    private func statRow(_ label: LocalizedStringKey, _ value: Int) -> some View {
        HStack {
            Text(label)
                .font(.caption.bold())
                .foregroundStyle(theme.textSecondary)
            Spacer()
            HStack(spacing: 3) {
                ForEach(1...5, id: \.self) { index in
                    Image(systemName: index <= value ? "pawprint.fill" : "pawprint")
                        .font(.caption)
                        .foregroundStyle(index <= value ? accent : theme.textSecondary.opacity(0.3))
                }
            }
            .accessibilityElement()
            .accessibilityLabel(Text("\(value) out of 5"))
        }
    }
}

/// Henüz kazanılmamış kartların yerine: "Yeni bir kedi seni bekliyor".
@MainActor
struct MysteryCardView: View {
    @Environment(\.appTheme) private var theme

    var body: some View {
        VStack(spacing: 8) {
            Image(systemName: "questionmark")
                .font(.title.bold())
                .foregroundStyle(theme.textSecondary)
            Text("A new cat awaits")
                .font(.caption2.bold())
                .multilineTextAlignment(.center)
                .foregroundStyle(theme.textSecondary)
        }
        .padding(8)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .aspectRatio(0.72, contentMode: .fit)
        .background(RoundedRectangle(cornerRadius: 14, style: .continuous).fill(theme.surfaceMuted))
        .overlay(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .strokeBorder(theme.separator, style: StrokeStyle(lineWidth: 2, dash: [5, 4]))
        )
    }
}

/// Kartın arka yüzü: ansiklopedi tarzı tür bilgisi.
@MainActor
struct BreedCardBackView: View {
    @Environment(\.appTheme) private var theme
    let chapter: Chapter
    let card: BreedCard

    private var accent: Color { chapter.accentColor.map { Color($0) } ?? theme.accent }

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(spacing: 12) {
                ChapterBadge(chapter: chapter, size: 52)
                VStack(alignment: .leading, spacing: 2) {
                    Text(verbatim: chapter.title.resolved)
                        .font(.title3.bold())
                        .foregroundStyle(theme.textPrimary)
                    Text(verbatim: card.origin.resolved)
                        .font(.subheadline)
                        .foregroundStyle(theme.textSecondary)
                }
                Spacer(minLength: 0)
                Text(verbatim: String(format: "#%02d", card.number))
                    .font(.subheadline.monospacedDigit().bold())
                    .foregroundStyle(theme.textSecondary)
            }

            Label("About the Breed", systemImage: "book.closed.fill")
                .font(.headline)
                .foregroundStyle(accent)

            Text(verbatim: (card.about ?? card.fact).resolved)
                .font(.callout)
                .foregroundStyle(theme.textPrimary)
                .lineSpacing(3)
                .fixedSize(horizontal: false, vertical: true)

            Divider()

            VStack(alignment: .leading, spacing: 6) {
                infoRow(icon: "hourglass", label: "Lifespan", value: Text("\(card.lifespan) years"))
                infoRow(icon: "paintbrush.pointed.fill", label: "Coat", value: Text(verbatim: card.coat.resolved))
            }
            .font(.subheadline)

            Spacer(minLength: 0)
        }
        .padding(18)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .background(
            RoundedRectangle(cornerRadius: 24, style: .continuous)
                .fill(LinearGradient(colors: [theme.surface, accent.opacity(0.25)], startPoint: .top, endPoint: .bottom))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 24, style: .continuous)
                .strokeBorder(
                    LinearGradient(colors: card.rarity.frameColors, startPoint: .topLeading, endPoint: .bottomTrailing),
                    lineWidth: 6
                )
        )
        .shadow(color: card.rarity.frameColors[1].opacity(0.35), radius: 12, y: 4)
        .accessibilityElement(children: .combine)
    }

    private func infoRow(icon: String, label: LocalizedStringKey, value: Text) -> some View {
        HStack(alignment: .firstTextBaseline, spacing: 8) {
            Image(systemName: icon)
                .foregroundStyle(accent)
                .frame(width: 20)
            Text(label)
                .foregroundStyle(theme.textSecondary)
            Spacer(minLength: 8)
            value
                .foregroundStyle(theme.textPrimary)
                .multilineTextAlignment(.trailing)
        }
    }
}

/// Dokununca 3B dönen kart: ön yüz kart, arka yüz tür bilgisi.
///
/// İki yüz de hep hiyerarşide durur; yalnızca açı ve görünürlük değişir. Boyut,
/// büyük olan yüze göre belirlenir, böylece dönerken kart zıplamaz.
@MainActor
struct FlippableBreedCard: View {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    let chapter: Chapter
    let card: BreedCard
    @State private var isFlipped = false

    var body: some View {
        ZStack {
            BreedCardView(chapter: chapter, card: card)
                .modifier(CardFaceFlip(angle: isFlipped ? 180 : 0, isBack: false))
                .accessibilityHidden(isFlipped)
            BreedCardBackView(chapter: chapter, card: card)
                .modifier(CardFaceFlip(angle: isFlipped ? 180 : 0, isBack: true))
                .accessibilityHidden(!isFlipped)
        }
        .contentShape(Rectangle())
        .onTapGesture {
            Haptics.selection()
            if reduceMotion {
                isFlipped.toggle()
            } else {
                withAnimation(.spring(duration: 0.6, bounce: 0.15)) { isFlipped.toggle() }
            }
        }
        .accessibilityAddTraits(.isButton)
        .accessibilityHint(Text("Tap to flip the card"))
        .accessibilityIdentifier("card.flip")
    }
}

/// Kartın bir yüzünü verilen açıya göre döndürür; yüz 90°'yi geçince görünmez olur.
/// Açı animasyonla ara değerler aldığı için iki yüz hiçbir anda üst üste görünmez.
private struct CardFaceFlip: ViewModifier, Animatable {
    var angle: Double
    let isBack: Bool

    var animatableData: Double {
        get { angle }
        set { angle = newValue }
    }

    func body(content: Content) -> some View {
        let isVisible = isBack ? angle >= 90 : angle < 90
        content
            .rotation3DEffect(.degrees(isBack ? angle - 180 : angle), axis: (x: 0, y: 1, z: 0), perspective: 0.5)
            .opacity(isVisible ? 1 : 0)
    }
}
