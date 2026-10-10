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

/// Pokemon kartı tarzında kedi türü kartı. `isGolden` ile Premium Altın Kart sürümü:
/// altın varak zemin ve çerçeve, altın tonlu portre ve taç, kayan parıltı ve yıldızcıklar.
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
    var isGolden = false

    private var accent: Color { isGolden ? Gold.deep : (chapter.accentColor.map { Color($0) } ?? theme.accent) }
    private var isCompact: Bool { style == .compact }
    /// Altın zeminde temadan bağımsız koyu mürekkep: koyu temada da okunur.
    private var ink: Color { isGolden ? Gold.ink : theme.textPrimary }
    private var inkSecondary: Color { isGolden ? Gold.ink.opacity(0.78) : theme.textSecondary }
    private var panel: Color { isGolden ? Gold.light.opacity(0.75) : theme.surfaceMuted }
    private var frameColors: [Color] { isGolden ? Gold.frame : card.rarity.frameColors }
    private var cornerRadius: CGFloat { isCompact ? 14 : 24 }

    var body: some View {
        let shape = RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
        VStack(alignment: .leading, spacing: isCompact ? 6 : 12) {
            header
            artwork
            if !isCompact {
                details
                statsView
                Text(verbatim: (isGolden ? card.goldenFact ?? card.fact : card.fact).resolved)
                    .font(.footnote.italic())
                    .foregroundStyle(ink)
                    .fixedSize(horizontal: false, vertical: true)
                    .padding(10)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(RoundedRectangle(cornerRadius: 10).fill(panel))
            }
        }
        .padding(isCompact ? 8 : 16)
        .background(
            shape.fill(isGolden
                ? LinearGradient(colors: [Gold.light, Gold.bright, Gold.light, Gold.mid.opacity(0.8)], startPoint: .topLeading, endPoint: .bottomTrailing)
                : LinearGradient(colors: [accent.opacity(0.35), theme.surface], startPoint: .top, endPoint: .bottom))
        )
        .overlay {
            if isGolden {
                GoldenShine(cornerRadius: cornerRadius, isCompact: isCompact)
            }
        }
        .overlay(
            shape.strokeBorder(
                LinearGradient(colors: frameColors, startPoint: .topLeading, endPoint: .bottomTrailing),
                lineWidth: isCompact ? 3 : 6
            )
        )
        .shadow(color: (isGolden ? Gold.deep : frameColors[1]).opacity(isGolden ? 0.5 : 0.35), radius: isCompact ? 4 : 12, y: 4)
        .accessibilityElement(children: .combine)
        .accessibilityValue(isGolden ? Text("Golden Card") : Text(verbatim: ""))
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: 2) {
            HStack(alignment: .firstTextBaseline) {
                Text(verbatim: chapter.title.resolved)
                    .font(isCompact ? .caption.bold() : .title3.bold())
                    .foregroundStyle(ink)
                    .lineLimit(1)
                    .minimumScaleFactor(0.7)
                Spacer(minLength: 4)
                Text(verbatim: String(format: "#%02d", card.number))
                    .font((isCompact ? Font.caption2 : Font.subheadline).monospacedDigit().bold())
                    .foregroundStyle(inkSecondary)
            }
            HStack(spacing: 2) {
                if isGolden {
                    Image(systemName: "crown.fill")
                    if !isCompact {
                        Text("Golden Card")
                            .padding(.leading, 4)
                    }
                } else {
                    ForEach(0..<card.rarity.stars, id: \.self) { _ in
                        Image(systemName: "star.fill")
                    }
                    if !isCompact {
                        Text(card.rarity.title)
                            .padding(.leading, 4)
                    }
                }
            }
            .font(isCompact ? .system(size: 8) : .caption.bold())
            .foregroundStyle(isGolden ? Gold.ink : frameColors[1])
        }
    }

    /// Assets'te "card-<tür>" adlı (lisanslı) bir fotoğraf varsa o, yoksa piksel portre.
    /// Altın Kartta portre altın tonlarında, koyu kadife zemin üzerinde ve taçlı.
    @ViewBuilder
    private var artwork: some View {
        let radius: CGFloat = isCompact ? 10 : 16
        ZStack {
            RoundedRectangle(cornerRadius: radius)
                .fill(isGolden
                    ? RadialGradient(colors: [Gold.dark.opacity(0.75), Gold.ink], center: .center, startRadius: 4, endRadius: 160)
                    : RadialGradient(colors: [accent.opacity(0.55), accent.opacity(0.15)], center: .top, startRadius: 0, endRadius: 220))
            if let photo = BreedPhoto.card(chapter.id) {
                // Altın Kartta aynı resim altın tonlarında
                Image(uiImage: photo)
                    .resizable()
                    .scaledToFill()
                    .grayscale(isGolden ? 1 : 0)
                    .colorMultiply(isGolden ? Gold.bright : .white)
                    .overlay {
                        if isGolden {
                            LinearGradient(colors: [Gold.light.opacity(0.35), .clear, Gold.deep.opacity(0.35)], startPoint: .topLeading, endPoint: .bottomTrailing)
                        }
                    }
                    .clipShape(RoundedRectangle(cornerRadius: radius))
            } else if let portrait = chapter.portrait {
                ArtworkThumbnail(artwork: portrait, goldTone: isGolden)
                    .padding(isCompact ? 8 : 18)
                    .padding(.top, isGolden ? (isCompact ? 8 : 18) : 0)
            }
            if isGolden {
                Image(systemName: "crown.fill")
                    .font(isCompact ? .caption : .title2)
                    .foregroundStyle(Gold.foil)
                    .shadow(color: .black.opacity(0.4), radius: 1, y: 1)
                    .frame(maxHeight: .infinity, alignment: .top)
                    .padding(.top, isCompact ? 3 : 8)
                    .accessibilityHidden(true)
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
                .foregroundStyle(inkSecondary)
            Spacer(minLength: 8)
            value
                .foregroundStyle(ink)
                .multilineTextAlignment(.trailing)
        }
    }

    /// Altın Kart efsanevi sürüm: tüm puanlar 5/5.
    private func score(_ value: Int) -> Int { isGolden ? 5 : value }

    private var statsView: some View {
        VStack(spacing: 6) {
            statRow("Energy", score(card.stats.energy))
            statRow("Affection", score(card.stats.affection))
            statRow("Playfulness", score(card.stats.playfulness))
            statRow("Grooming", score(card.stats.grooming))
        }
        .padding(10)
        .background(RoundedRectangle(cornerRadius: 10).fill(panel.opacity(isGolden ? 1 : 0.6)))
    }

    private func statRow(_ label: LocalizedStringKey, _ value: Int) -> some View {
        HStack {
            Text(label)
                .font(.caption.bold())
                .foregroundStyle(inkSecondary)
            Spacer()
            HStack(spacing: 3) {
                ForEach(1...5, id: \.self) { index in
                    Image(systemName: index <= value ? "pawprint.fill" : "pawprint")
                        .font(.caption)
                        .foregroundStyle(index <= value ? accent : inkSecondary.opacity(0.35))
                }
            }
            .accessibilityElement()
            .accessibilityLabel(Text("\(value) out of 5"))
        }
    }
}

/// Altın Kartın üstünden kayan ışık şeridi ve yanıp sönen yıldızcıklar.
/// Dokunmayı engellemez; "Hareketi Azalt" açıkken durağan kalır.
@MainActor
private struct GoldenShine: View {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    let cornerRadius: CGFloat
    let isCompact: Bool
    @State private var sweep = false
    @State private var twinkle = false

    /// Kartın üzerindeki yıldızcık konumları (birim koordinat) ve boyutları.
    private static let sparkles: [(CGFloat, CGFloat, CGFloat)] = [
        (0.12, 0.10, 1.0), (0.86, 0.18, 0.7), (0.78, 0.46, 0.9), (0.18, 0.55, 0.6), (0.9, 0.86, 0.8), (0.3, 0.9, 0.5),
    ]

    var body: some View {
        GeometryReader { proxy in
            let size = proxy.size
            ZStack {
                if !reduceMotion {
                    LinearGradient(
                        colors: [.white.opacity(0), .white.opacity(isCompact ? 0.35 : 0.5), .white.opacity(0)],
                        startPoint: .leading,
                        endPoint: .trailing
                    )
                    .frame(width: size.width * 0.35, height: size.height * 1.6)
                    .rotationEffect(.degrees(20))
                    .offset(x: sweep ? size.width * 0.9 : -size.width * 0.9)
                    .blendMode(.plusLighter)
                }
                ForEach(Array(Self.sparkles.enumerated()), id: \.offset) { index, sparkle in
                    Image(systemName: "sparkle")
                        .font(.system(size: (isCompact ? 7 : 14) * sparkle.2))
                        .foregroundStyle(.white)
                        .shadow(color: Gold.bright, radius: 2)
                        .opacity(reduceMotion ? 0.8 : (twinkle == (index % 2 == 0) ? 1 : 0.2))
                        .scaleEffect(reduceMotion ? 1 : (twinkle == (index % 2 == 0) ? 1 : 0.6))
                        .position(x: size.width * sparkle.0, y: size.height * sparkle.1)
                }
            }
            .frame(width: size.width, height: size.height)
        }
        .clipShape(RoundedRectangle(cornerRadius: cornerRadius, style: .continuous))
        .allowsHitTesting(false)
        .accessibilityHidden(true)
        .onAppear {
            guard !reduceMotion else { return }
            withAnimation(.easeInOut(duration: 2.4).delay(0.6).repeatForever(autoreverses: false)) { sweep = true }
            withAnimation(.easeInOut(duration: 1.1).repeatForever(autoreverses: true)) { twinkle = true }
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
    var isGolden = false

    private var accent: Color { isGolden ? Gold.deep : (chapter.accentColor.map { Color($0) } ?? theme.accent) }
    private var ink: Color { isGolden ? Gold.ink : theme.textPrimary }
    private var inkSecondary: Color { isGolden ? Gold.ink.opacity(0.78) : theme.textSecondary }

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(spacing: 12) {
                ChapterBadge(chapter: chapter, size: 52)
                VStack(alignment: .leading, spacing: 2) {
                    Text(verbatim: chapter.title.resolved)
                        .font(.title3.bold())
                        .foregroundStyle(ink)
                    Text(verbatim: card.origin.resolved)
                        .font(.subheadline)
                        .foregroundStyle(inkSecondary)
                }
                Spacer(minLength: 0)
                Text(verbatim: String(format: "#%02d", card.number))
                    .font(.subheadline.monospacedDigit().bold())
                    .foregroundStyle(inkSecondary)
            }

            // Altın Kart: normal kartın arkasındakinden farklı, daha ayrıntılı geçmiş ve bakım rehberi
            let golden = isGolden ? card.goldenAbout : nil
            Label(golden == nil ? "About the Breed" : "Breed Story", systemImage: golden == nil ? "book.closed.fill" : "crown.fill")
                .font(.headline)
                .foregroundStyle(accent)

            Text(verbatim: (golden ?? card.about ?? card.fact).resolved)
                .font(golden == nil ? .callout : .footnote)
                .foregroundStyle(ink)
                .lineSpacing(3)
                .fixedSize(horizontal: false, vertical: true)

            if isGolden, let care = card.care {
                Label("Care Guide", systemImage: "heart.text.square.fill")
                    .font(.headline)
                    .foregroundStyle(accent)
                Text(verbatim: care.resolved)
                    .font(.footnote)
                    .foregroundStyle(ink)
                    .lineSpacing(3)
                    .fixedSize(horizontal: false, vertical: true)
            }

            Divider()

            VStack(alignment: .leading, spacing: 6) {
                infoRow(icon: "hourglass", label: "Lifespan", value: Text("\(card.lifespan) years"))
                if isGolden, let weight = card.weight {
                    infoRow(icon: "scalemass.fill", label: "Weight", value: Text(verbatim: weight))
                }
                infoRow(icon: "paintbrush.pointed.fill", label: "Coat", value: Text(verbatim: card.coat.resolved))
            }
            .font(.subheadline)

            Spacer(minLength: 0)
        }
        .padding(18)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .background(
            RoundedRectangle(cornerRadius: 24, style: .continuous)
                .fill(isGolden
                    ? LinearGradient(colors: [Gold.light, Gold.bright.opacity(0.9), Gold.light], startPoint: .top, endPoint: .bottom)
                    : LinearGradient(colors: [theme.surface, accent.opacity(0.25)], startPoint: .top, endPoint: .bottom))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 24, style: .continuous)
                .strokeBorder(
                    LinearGradient(colors: isGolden ? Gold.frame : card.rarity.frameColors, startPoint: .topLeading, endPoint: .bottomTrailing),
                    lineWidth: 6
                )
        )
        .shadow(color: (isGolden ? Gold.deep : card.rarity.frameColors[1]).opacity(0.35), radius: 12, y: 4)
        .accessibilityElement(children: .combine)
    }

    private func infoRow(icon: String, label: LocalizedStringKey, value: Text) -> some View {
        HStack(alignment: .firstTextBaseline, spacing: 8) {
            Image(systemName: icon)
                .foregroundStyle(accent)
                .frame(width: 20)
            Text(label)
                .foregroundStyle(inkSecondary)
            Spacer(minLength: 8)
            value
                .foregroundStyle(ink)
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
    var isGolden = false
    @State private var isFlipped = false

    var body: some View {
        ZStack {
            BreedCardView(chapter: chapter, card: card, isGolden: isGolden)
                .modifier(CardFaceFlip(angle: isFlipped ? 180 : 0, isBack: false))
                .accessibilityHidden(isFlipped)
            BreedCardBackView(chapter: chapter, card: card, isGolden: isGolden)
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
