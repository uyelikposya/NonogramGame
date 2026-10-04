import NonogramKit
import SwiftUI

/// Kedinin konuşma balonunda söyledikleri.
enum CompanionLine: Equatable {
    case hint(HintFinder.Hint)
    case noHint
}

/// Bulmaca ekranında tahtanın altındaki boşlukta dolaşan küçük kedi.
///
/// Kendi başına yürür, oturur, kendini yalar, uyur ve kalp çıkarır. Dokununca
/// `onTap` çağrılır; oyun ekranı bir ipucu bulup `line` ile kediye söyletir.
/// Tahtanın dokunma alanıyla çakışmaz; yalnızca kendi alanındaki kedi dokunulabilir.
@MainActor
struct CatCompanionView: View {
    @Environment(\.appTheme) private var theme
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    /// Balonda gösterilecek söz; `nil` ise kedi kendi işinde.
    var line: CompanionLine?
    var isActive = true
    let onTap: () -> Void

    @State private var position: CGFloat = 0.15
    @State private var facingRight = true
    @State private var pose: CatPose = .sit
    @State private var hearts: [Int] = []
    @State private var nextHeart = 0
    @State private var areaWidth: CGFloat = 0
    @State private var isTalking = false

    private static let pixel: CGFloat = 4
    private static let catWidth = CGFloat(CatPose.columns) * pixel
    private static let catHeight = CGFloat(CatPose.rows) * pixel
    /// Kedinin sığabilmesi için gereken en az yükseklik; daha azsa hiç gösterilmez.
    static let minimumHeight = catHeight + 8

    var body: some View {
        GeometryReader { proxy in
            let travel = max(proxy.size.width - Self.catWidth, 0)
            let catX = position * travel
            let fits = proxy.size.height >= Self.minimumHeight

            ZStack(alignment: .bottomLeading) {
                cat
                    .offset(x: catX)

                if let line {
                    // Balon kedinin geniş olan tarafında açılır
                    let onRight = position < 0.5
                    let available = max(onRight ? proxy.size.width - catX - Self.catWidth - 10 : catX - 10, 0)
                    bubble(for: line)
                        .frame(maxWidth: available, alignment: onRight ? .leading : .trailing)
                        .offset(x: onRight ? catX + Self.catWidth + 6 : catX - 6 - available)
                        .padding(.bottom, Self.catHeight * 0.35)
                        .transition(.scale(scale: 0.6, anchor: onRight ? .bottomLeading : .bottomTrailing).combined(with: .opacity))
                }
            }
            .frame(width: proxy.size.width, height: proxy.size.height, alignment: .bottomLeading)
            .opacity(fits && isActive ? 1 : 0)
            .allowsHitTesting(fits && isActive)
            .onAppear { areaWidth = proxy.size.width }
            .onChange(of: proxy.size.width) { _, width in areaWidth = width }
        }
        .animation(.spring(duration: 0.35), value: line)
        .onChange(of: line) { _, newValue in
            isTalking = newValue != nil
            if isTalking { pose = .sit }
        }
        .task { await live() }
    }

    private var cat: some View {
        CatSprite(pose: pose, pixel: Self.pixel, fur: Color(hex: "#F7A862"), furShade: Color(hex: "#E68C50"))
            .scaleEffect(x: facingRight ? 1 : -1)
            .overlay(alignment: .top) {
                ZStack {
                    ForEach(hearts, id: \.self) { id in
                        FloatingHeart(color: theme.accent, drift: id % 2 == 0 ? -8 : 8)
                    }
                }
                .allowsHitTesting(false)
            }
            .frame(width: Self.catWidth, height: Self.catHeight)
            .contentShape(Rectangle())
            .onTapGesture {
                onTap()
                popHeart()
            }
            .accessibilityElement()
            .accessibilityLabel(Text("Cat helper"))
            .accessibilityHint(Text("Tap for a hint"))
            .accessibilityAddTraits(.isButton)
            .accessibilityIdentifier("game.companion")
    }

    private func bubble(for line: CompanionLine) -> some View {
        Group {
            switch line {
            case .hint(let hint):
                switch hint.axis {
                case .row: Text("Psst! Look at row \(hint.index + 1).")
                case .column: Text("Psst! Look at column \(hint.index + 1).")
                }
            case .noHint:
                Text("Purr… I can't spot a sure move. Check your marks!")
            }
        }
        .font(.footnote.weight(.semibold))
        .foregroundStyle(theme.textPrimary)
        .fixedSize(horizontal: false, vertical: true)
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .background(Capsule(style: .continuous).fill(theme.surface))
        .overlay(Capsule(style: .continuous).strokeBorder(theme.accent.opacity(0.5), lineWidth: 1.5))
        .shadow(color: .black.opacity(0.08), radius: 4, y: 2)
        .allowsHitTesting(false)
    }

    // MARK: - Davranış

    /// Kedinin kendi kafasına göre yaşadığı döngü. Ekran kapanınca görev iptal olur.
    private func live() async {
        while !Task.isCancelled {
            if isTalking || reduceMotion {
                pose = .sit
                await pause(0.5)
                continue
            }
            switch Int.random(in: 0..<10) {
            case 0..<4: await walk()
            case 4..<6: await groom()
            case 6: await nap()
            case 7: await showLove()
            default:
                pose = .sit
                await pause(Double.random(in: 1.5...3))
            }
        }
    }

    private func walk() async {
        let travel = max(areaWidth - Self.catWidth, 1)
        var target = CGFloat.random(in: 0...1)
        if abs(target - position) * travel < 40 { target = position < 0.5 ? min(position + 0.5, 1) : max(position - 0.5, 0) }
        facingRight = target > position
        // Yaklaşık 28 pt/sn: telaşsız bir yürüyüş
        let duration = Double(abs(target - position) * travel / 28)
        withAnimation(.linear(duration: duration)) { position = target }
        var elapsed = 0.0
        var step = false
        while elapsed < duration, !Task.isCancelled, !isTalking {
            step.toggle()
            pose = step ? .walk1 : .walk2
            await pause(0.2)
            elapsed += 0.2
        }
        pose = .sit
    }

    private func groom() async {
        pose = .sit
        for _ in 0..<Int.random(in: 3...5) where !isTalking && !Task.isCancelled {
            pose = .lick1
            await pause(0.35)
            pose = .lick2
            await pause(0.35)
        }
        pose = .sit
        await pause(1)
    }

    private func nap() async {
        pose = .sleep
        var slept = 0.0
        let length = Double.random(in: 4...7)
        while slept < length, !isTalking, !Task.isCancelled {
            await pause(0.5)
            slept += 0.5
        }
        pose = .sit
    }

    private func showLove() async {
        pose = .sit
        for _ in 0..<3 where !Task.isCancelled {
            popHeart()
            await pause(0.45)
        }
        await pause(1.2)
    }

    private func popHeart() {
        let id = nextHeart
        nextHeart += 1
        hearts.append(id)
        Task {
            try? await Task.sleep(for: .seconds(1.3))
            hearts.removeAll { $0 == id }
        }
    }

    private func pause(_ seconds: Double) async {
        try? await Task.sleep(for: .seconds(seconds))
    }
}

/// Yukarı süzülüp kaybolan küçük kalp.
@MainActor
private struct FloatingHeart: View {
    let color: Color
    let drift: CGFloat
    @State private var isRising = false

    var body: some View {
        Image(systemName: "heart.fill")
            .font(.system(size: 11))
            .foregroundStyle(color)
            .offset(x: isRising ? drift : 0, y: isRising ? -30 : 0)
            .opacity(isRising ? 0 : 1)
            .scaleEffect(isRising ? 1.2 : 0.6)
            .onAppear {
                withAnimation(.easeOut(duration: 1.2)) { isRising = true }
            }
    }
}

/// Kedinin piksel çizimleri (sağa bakar; sola bakarken yatay çevrilir).
enum CatPose: CaseIterable {
    case walk1, walk2, sit, lick1, lick2, sleep

    static let columns = 16
    static let rows = 11

    /// `#` tüy, `r` gölgeli tüy (pati), `d`/`-` göz, `p`/`t` burun/dil, `w` krem.
    var pattern: [String] {
        switch self {
        case .walk1: [
            "................",
            "...........#...#",
            "...........##.##",
            "...........#####",
            "#..........#d#d#",
            "#..........##p##",
            ".#..#########w#.",
            "..###########...",
            "...##########...",
            "...#.#....#.#...",
            "..#...#..#...#..",
        ]
        case .walk2: [
            "................",
            "...........#...#",
            "...........##.##",
            "...........#####",
            "..#........#d#d#",
            ".#.........##p##",
            ".#..#########w#.",
            "..###########...",
            "...##########...",
            "....#.#..#.#....",
            "....#.#..#.#....",
        ]
        case .sit: [
            "......#...#.....",
            "......##.##.....",
            "......#####.....",
            "......#d#d#.....",
            "......##p##.....",
            ".......#w#......",
            "......#####.....",
            ".....#######....",
            ".....###w###....",
            "..##.#######....",
            "...########.....",
        ]
        case .lick1: [
            "......#...#.....",
            "......##.##.....",
            "......#####.....",
            "......#-#-#.....",
            "....r.##p##.....",
            "....rr.#t#......",
            "......#####.....",
            ".....#######....",
            ".....#######....",
            "..##.#######....",
            "...########.....",
        ]
        case .lick2: [
            "......#...#.....",
            "......##.##.....",
            "......#####.....",
            "......#-#-#.....",
            "......##p##.....",
            "....rr.#w#......",
            "....rr#####.....",
            ".....#######....",
            ".....#######....",
            "..##.#######....",
            "...########.....",
        ]
        case .sleep: [
            "................",
            "................",
            "................",
            "................",
            "................",
            "...........#...#",
            "...........##.##",
            "....#######-#-##",
            "..###########p##",
            ".#############w.",
            "..############..",
        ]
        }
    }
}

/// Bir pozu tek `Canvas` ile çizer.
@MainActor
struct CatSprite: View {
    let pose: CatPose
    let pixel: CGFloat
    let fur: Color
    let furShade: Color

    private static let dark = Color(hex: "#3B2F2F")
    private static let pink = Color(hex: "#E8707E")
    private static let cream = Color(hex: "#FFF3E4")

    var body: some View {
        let pattern = pose.pattern
        let pixel = pixel
        let colors: [Character: Color] = [
            "#": fur, "r": furShade, "d": Self.dark, "-": Self.dark,
            "p": Self.pink, "t": Self.pink, "w": Self.cream,
        ]
        Canvas { context, _ in
            for (y, row) in pattern.enumerated() {
                for (x, symbol) in row.enumerated() {
                    guard let color = colors[symbol] else { continue }
                    let rect = CGRect(x: CGFloat(x) * pixel, y: CGFloat(y) * pixel, width: pixel, height: pixel)
                    context.fill(Path(rect), with: .color(color))
                }
            }
        }
        .frame(width: CGFloat(CatPose.columns) * pixel, height: CGFloat(CatPose.rows) * pixel)
        .accessibilityHidden(true)
    }
}
