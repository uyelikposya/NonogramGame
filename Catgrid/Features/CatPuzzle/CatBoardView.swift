import NonogramKit
import SwiftUI

/// Kedi Bulmaca tahtası: renkli kareler tek `Canvas` ile çizilir (bulunan kedilerin portresi
/// dahil), böylece sürüklerken görünüm eklenip çıkarılmaz ve dokunma kesilmez.
@MainActor
struct CatBoardView: View {
    @Environment(\.appTheme) private var theme
    let game: CatGame
    let cats: CatPuzzleModel
    var activeCell: GridPosition?
    var wrongCell: GridPosition?
    var hint: CatHint?
    /// Eğitimde dokunulacak kare.
    var pointer: GridPosition?
    var effects: [CatEffect] = []
    var banner: CatBanner?
    var animations: [GridPosition: CatMarkAnimation] = [:]
    var conflict: CatConflict?
    let onBegan: (GridPosition) -> Void
    let onMoved: (GridPosition) -> Void
    let onEnded: () -> Void

    @State private var isTouching = false
    @GestureState private var touching = false

    var body: some View {
        GeometryReader { proxy in
            let side = min(proxy.size.width, proxy.size.height)
            let cell = side / CGFloat(game.size)
            canvas(cell: cell)
                .frame(width: side, height: side)
                .contentShape(Rectangle())
                .gesture(drag(cell: cell))
                .overlay(alignment: .topLeading) {
                    ZStack(alignment: .topLeading) {
                        ForEach(effects) { effect in
                            CatEffectView(effect: effect)
                                .position(
                                    x: (CGFloat(effect.position.column) + 0.5) * cell,
                                    y: (CGFloat(effect.position.row) + 0.5) * cell
                                )
                        }
                        PawPointer()
                            .offset(
                                x: CGFloat(pointer?.column ?? 0) * cell + cell * 0.45,
                                y: CGFloat(pointer?.row ?? 0) * cell + cell * 0.5
                            )
                            .opacity(pointer == nil ? 0 : 1)
                    }
                    .frame(width: side, height: side, alignment: .topLeading)
                    .allowsHitTesting(false)
                }
                .overlay {
                    // Motivasyon yazısı tahtanın ortasında büyük
                    if let banner {
                        CatBannerView(banner: banner)
                            .id(banner.id)
                            .allowsHitTesting(false)
                    }
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
        .onChange(of: touching) { _, isDown in
            guard !isDown, isTouching else { return }
            isTouching = false
            onEnded()
        }
        .accessibilityElement()
        .accessibilityLabel(Text("Puzzle board"))
        .accessibilityValue(Text("\(game.foundCount) of \(game.size) cats found"))
        .accessibilityIdentifier("cat.board")
    }

    private func drag(cell: CGFloat) -> some Gesture {
        DragGesture(minimumDistance: 0)
            .updating($touching) { _, state, _ in state = true }
            .onChanged { value in
                let position = GridPosition(
                    row: Int(max(value.location.y, 0) / cell),
                    column: Int(max(value.location.x, 0) / cell)
                )
                if isTouching {
                    onMoved(position)
                } else {
                    isTouching = true
                    onBegan(position)
                }
            }
            .onEnded { _ in
                guard isTouching else { return }
                isTouching = false
                onEnded()
            }
    }

    private func canvas(cell: CGFloat) -> some View {
        let level = game.level
        let portraits = Dictionary(uniqueKeysWithValues: (0..<level.size).compactMap { region -> (Int, Image)? in
            guard let chapter = cats.breed(level.breeds[region]), let image = PortraitImages.image(for: chapter) else { return nil }
            return (region, image)
        })
        let painter = CatBoardPainter(
            game: game,
            cell: cell,
            theme: theme,
            activeCell: activeCell,
            wrongCell: wrongCell,
            hint: hint,
            focus: Set(hint?.focus ?? []),
            targets: Set(hint?.cells ?? []),
            animations: animations,
            conflictCells: Set(conflictCells(in: level)),
            portraits: portraits
        )
        // Animasyon varken zaman çizelgesi işler; yoksa durur
        return TimelineView(.animation(paused: painter.isStill)) { timeline in
            Canvas { context, size in
                painter.draw(in: context, size: size, now: timeline.date)
            }
        }
    }

    /// Yanlış kedinin çeliştiği satır/sütun/renk ya da değdiği kedi.
    private func conflictCells(in level: CatLevel) -> [GridPosition] {
        guard let conflict else { return [] }
        let n = level.size
        switch conflict {
        case .line(let group):
            return CatRules.cells(of: group, in: level).map { GridPosition(row: $0 / n, column: $0 % n) }
        case .color(let region):
            return level.cells(ofRegion: region)
        case .touching(let position):
            return [position]
        }
    }

}

/// Tahtanın çizimi (Canvas içinde); her kare ayrı fonksiyonda, derleyiciyi yormaz.
struct CatBoardPainter {
    let game: CatGame
    let cell: CGFloat
    let theme: AppTheme
    let activeCell: GridPosition?
    let wrongCell: GridPosition?
    let hint: CatHint?
    let focus: Set<GridPosition>
    let targets: Set<GridPosition>
    let animations: [GridPosition: CatMarkAnimation]
    let conflictCells: Set<GridPosition>
    let portraits: [Int: Image]

    var isStill: Bool { animations.isEmpty && conflictCells.isEmpty }

    func draw(in context: GraphicsContext, size: CGSize, now: Date) {
        context.fill(Path(roundedRect: CGRect(origin: .zero, size: size), cornerRadius: 12), with: .color(theme.surface))
        for row in 0..<game.size {
            for column in 0..<game.size {
                drawCell(GridPosition(row: row, column: column), in: context, now: now)
            }
        }
    }

    private func progress(of animation: CatMarkAnimation?, now: Date) -> Double {
        guard let animation else { return 1 }
        return min(max(now.timeIntervalSince(animation.start) / CatMarkAnimation.duration, 0), 1)
    }

    private func drawCell(_ position: GridPosition, in context: GraphicsContext, now: Date) {
        let animation = animations[position]
        let progress = progress(of: animation, now: now)
        let mark = game[position]
        let gap = max(cell * 0.06, 1.5)
        var rect = CGRect(x: CGFloat(position.column) * cell, y: CGFloat(position.row) * cell, width: cell, height: cell)
            .insetBy(dx: gap / 2, dy: gap / 2)
        // Yanlış kedi: kare kısa süre sallanır
        if animation?.kind == .wrong, progress < 1 {
            rect = rect.offsetBy(dx: sin(progress * .pi * 6) * cell * 0.1 * (1 - progress), dy: 0)
        }
        let tile = Path(roundedRect: rect, cornerRadius: cell * 0.14)
        let region = game.level.region(at: position)
        context.fill(tile, with: .color(mark == .wrong ? theme.mistake : CatPalette.color(region)))
        if position == activeCell {
            context.fill(tile, with: .color(.white.opacity(0.25)))
        }
        switch mark {
        case .cross, .wrong:
            // X iki çizgiyle çizilerek gelir
            let drawn = animation == nil ? 1 : min(progress / 0.6, 1)
            context.stroke(
                Self.crossPath(in: rect.insetBy(dx: cell * 0.27, dy: cell * 0.27), progress: drawn),
                with: .color(.white),
                style: StrokeStyle(lineWidth: max(cell * 0.1, 2), lineCap: .round)
            )
        case .cat:
            drawCat(in: rect, tile: tile, region: region, scale: animation?.kind == .cat ? Self.popScale(progress) : 1, context: context)
        case .blank:
            break
        }
        if position == wrongCell {
            context.stroke(tile, with: .color(.white), lineWidth: 3)
        }
        // Yanlış kedinin bozduğu kuralın kareleri kırmızı çerçeveyle yanıp söner
        if conflictCells.contains(position) {
            let pulse = 0.55 + 0.45 * sin(now.timeIntervalSinceReferenceDate * 8)
            context.stroke(tile, with: .color(theme.mistake.opacity(pulse)), lineWidth: max(cell * 0.09, 2.5))
        }
        if hint != nil {
            drawHint(at: position, rect: rect, tile: tile, mark: mark, context: context)
        }
    }

    private func drawCat(in rect: CGRect, tile: Path, region: Int, scale: Double, context: GraphicsContext) {
        context.fill(tile, with: .color(.white.opacity(0.35)))
        guard let image = portraits[region] else { return }
        let inner = rect.insetBy(dx: cell * 0.08, dy: cell * 0.08)
        let width = inner.width * scale
        let height = inner.height * scale
        let target = CGRect(x: inner.midX - width / 2, y: inner.midY - height / 2, width: width, height: height)
        // Fotoğraf portreler yuvarlak kırpılır
        var clipped = context
        clipped.clip(to: Path(ellipseIn: target))
        clipped.draw(image, in: target)
    }

    /// İpucu önizlemesi: nedeni gösteren kareler aydınlık, diğerleri karartılır;
    /// X konacak kareler kesik çizgili çerçeve ve soluk X ile.
    private func drawHint(at position: GridPosition, rect: CGRect, tile: Path, mark: CatMark, context: GraphicsContext) {
        if !focus.contains(position), !targets.contains(position) {
            context.fill(tile, with: .color(.black.opacity(0.45)))
        }
        guard targets.contains(position) else { return }
        context.stroke(tile, with: .color(.white), style: StrokeStyle(lineWidth: 2.5, dash: [5, 4]))
        if case .onlySpot = hint?.kind {
            context.fill(Path(ellipseIn: rect.insetBy(dx: cell * 0.3, dy: cell * 0.3)), with: .color(.white.opacity(0.85)))
        } else if mark == .blank {
            context.stroke(
                Self.crossPath(in: rect.insetBy(dx: cell * 0.3, dy: cell * 0.3), progress: 1),
                with: .color(.white.opacity(0.6)),
                style: StrokeStyle(lineWidth: max(cell * 0.08, 1.5), lineCap: .round)
            )
        }
    }

    /// X: ilk yarıda bir çizgi, ikinci yarıda diğeri.
    static func crossPath(in rect: CGRect, progress: Double) -> Path {
        var path = Path()
        let first = min(progress * 2, 1)
        let second = max(progress * 2 - 1, 0)
        path.move(to: rect.origin)
        path.addLine(to: CGPoint(x: rect.minX + rect.width * first, y: rect.minY + rect.height * first))
        if second > 0 {
            path.move(to: CGPoint(x: rect.maxX, y: rect.minY))
            path.addLine(to: CGPoint(x: rect.maxX - rect.width * second, y: rect.minY + rect.height * second))
        }
        return path
    }

    /// Hafifçe taşan büyüme (0.3 → ~1.1 → 1).
    static func popScale(_ t: Double) -> Double {
        let c1 = 1.70158
        let c3 = c1 + 1
        let x = t - 1
        return 0.3 + 0.7 * (1 + c3 * x * x * x + c1 * x * x)
    }
}

/// Türlerin piksel portreleri bir kez resme çevrilip saklanır (tahtada hızlı çizim için).
@MainActor
enum PortraitImages {
    private static var cache: [String: Image] = [:]

    static func image(for chapter: Chapter) -> Image? {
        if let image = cache[chapter.id] { return image }
        if let photo = BreedPhoto.portrait(chapter.id) {
            let image = Image(uiImage: photo)
            cache[chapter.id] = image
            return image
        }
        guard let portrait = chapter.portrait else { return nil }
        let renderer = ImageRenderer(content: ArtworkThumbnail(artwork: portrait, outlined: false).frame(width: 96, height: 96))
        renderer.scale = 2
        guard let uiImage = renderer.uiImage else { return nil }
        let image = Image(uiImage: uiImage)
        cache[chapter.id] = image
        return image
    }
}

/// Kedinin üstünde uçuşan yazı.
@MainActor
struct CatEffectView: View {
    let effect: CatEffect
    @State private var lifted = false

    var body: some View {
        label
            .font(.system(size: 17, weight: .heavy, design: .rounded))
            .foregroundStyle(.white)
            .shadow(color: .black.opacity(0.45), radius: 2, y: 1)
            .fixedSize()
            .offset(y: lifted ? offset - 34 : offset)
            .opacity(lifted ? 0 : 1)
            .scaleEffect(lifted ? 1.1 : 0.7)
            .onAppear {
                withAnimation(.easeOut(duration: 1.3)) { lifted = true }
            }
    }

    private var offset: CGFloat {
        switch effect.kind {
        case .points: -18
        case .clear: 14
        }
    }

    @ViewBuilder
    private var label: some View {
        switch effect.kind {
        case .points(let points):
            Text(verbatim: "+\(points)")
                .foregroundStyle(Color(red: 1, green: 0.78, blue: 0.3))
        case .clear:
            Text("Clear!")
                .foregroundStyle(Color(red: 1, green: 0.9, blue: 0.4))
        }
    }
}

/// Tahtanın ortasındaki büyük motivasyon yazısı: "Bulundu!", "Harika!", "Tam isabet!"…
@MainActor
struct CatBannerView: View {
    @Environment(\.appTheme) private var theme
    let banner: CatBanner
    @State private var shown = false

    var body: some View {
        Group {
            if case .allFound(let variant) = banner.kind {
                HStack(spacing: 10) {
                    Image(systemName: "pawprint.fill")
                        .foregroundStyle(theme.accent)
                    allFoundText(variant)
                        .font(.headline)
                        .foregroundStyle(.white)
                        .multilineTextAlignment(.center)
                }
                .padding(.horizontal, 18)
                .padding(.vertical, 14)
                .background(RoundedRectangle(cornerRadius: 18).fill(.black.opacity(0.72)))
                .padding(24)
            } else {
                word
                    .font(.system(size: 40, weight: .black, design: .rounded))
                    .foregroundStyle(LinearGradient(colors: colors, startPoint: .top, endPoint: .bottom))
                    .shadow(color: .black.opacity(0.35), radius: 4, y: 2)
                    .multilineTextAlignment(.center)
                    .minimumScaleFactor(0.5)
                    .padding(.horizontal, 12)
            }
        }
        .scaleEffect(shown ? 1 : 0.4)
        .opacity(shown ? 1 : 0)
        .task {
            withAnimation(.spring(response: 0.32, dampingFraction: 0.55)) { shown = true }
            try? await Task.sleep(for: .seconds(0.9))
            withAnimation(.easeIn(duration: 0.3)) { shown = false }
        }
    }

    @ViewBuilder
    private func allFoundText(_ variant: Int) -> some View {
        switch variant {
        case 0: Text("The cats didn't even have time to hide!")
        case 1: Text("Every cat is found. Nothing gets past you!")
        default: Text("Hide and seek is over. You win!")
        }
    }

    @ViewBuilder
    private var word: some View {
        switch banner.kind {
        case .found: Text("Found!")
        case .perfectlyMarked: Text("Perfectly marked!")
        case .combo(let count):
            switch count {
            case 2: Text("Nice!")
            case 3: Text("Great!")
            case 4: Text("Perfect!")
            case 5: Text("Excellent!")
            case 6: Text("Amazing!")
            default: Text("Unstoppable!")
            }
        case .allFound: EmptyView()
        }
    }

    private var colors: [Color] {
        switch banner.kind {
        case .found:
            return [Color(red: 1, green: 0.88, blue: 0.45), Color(red: 1, green: 0.55, blue: 0.15)]
        case .perfectlyMarked:
            return [Color(red: 1, green: 0.95, blue: 0.5), Color(red: 0.95, green: 0.7, blue: 0.1)]
        case .allFound:
            return [.white, .white]
        case .combo(let count):
            switch count {
            case 2: return [Color(red: 0.5, green: 0.85, blue: 1), Color(red: 0.2, green: 0.55, blue: 0.95)]
            case 3: return [Color(red: 0.6, green: 0.95, blue: 0.6), Color(red: 0.2, green: 0.7, blue: 0.35)]
            case 4: return [Color(red: 0.4, green: 0.9, blue: 1), Color(red: 0.1, green: 0.5, blue: 0.9)]
            case 5: return [Color(red: 1, green: 0.85, blue: 0.4), Color(red: 1, green: 0.55, blue: 0.1)]
            default: return [Color(red: 1, green: 0.6, blue: 0.9), Color(red: 0.75, green: 0.3, blue: 0.95)]
            }
        }
    }
}

/// "?" ipucunun açıklaması (tahtanın üstünde).
@MainActor
struct CatHintCard: View {
    @Environment(\.appTheme) private var theme
    let hint: CatHint

    var body: some View {
        HStack(alignment: .top, spacing: 10) {
            Image(systemName: "lightbulb.fill")
                .foregroundStyle(Color(red: 0.98, green: 0.75, blue: 0.2))
            Text(hint.message)
                .font(.subheadline.weight(.medium))
                .foregroundStyle(theme.textPrimary)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(RoundedRectangle(cornerRadius: 16).fill(theme.surface).shadow(color: .black.opacity(0.2), radius: 8, y: 3))
        .padding(.horizontal, 8)
    }
}

extension CatHint {
    var message: LocalizedStringResource {
        switch kind {
        case .placedCat:
            return "No other cat can be in this cat's row, column or color, or right next to it."
        case .onlySpot(let group):
            switch group.axis {
            case .row: return "This row has only one spot left for its cat."
            case .column: return "This column has only one spot left for its cat."
            case .region: return "This color has only one spot left for its cat."
            }
        case .regionsFillLines(let axis, let count):
            if count == 1 {
                return axis == .row
                    ? "This color fits in a single row, so no other cat can be in the rest of that row."
                    : "This color fits in a single column, so no other cat can be in the rest of that column."
            }
            return axis == .row
                ? "These colors fit in exactly as many rows, so other colors can't have a cat in those rows."
                : "These colors fit in exactly as many columns, so other colors can't have a cat in those columns."
        case .linesFillRegions(let axis, let count):
            if count == 1 {
                return axis == .row
                    ? "Every free spot in this row belongs to one color, so that color's cat can't be anywhere else."
                    : "Every free spot in this column belongs to one color, so that color's cat can't be anywhere else."
            }
            return axis == .row
                ? "These rows only have free spots in as many colors, so those colors' cats can't be anywhere else."
                : "These columns only have free spots in as many colors, so those colors' cats can't be anywhere else."
        case .wouldEmpty(let group):
            switch group.axis {
            case .row: return "A cat here would leave no room for a cat in the highlighted row."
            case .column: return "A cat here would leave no room for a cat in the highlighted column."
            case .region: return "A cat here would leave no room for a cat in the highlighted color."
            }
        case .deadEnd(let group):
            switch group.axis {
            case .row: return "A cat here leads to a dead end: the highlighted row would soon have no room left."
            case .column: return "A cat here leads to a dead end: the highlighted column would soon have no room left."
            case .region: return "A cat here leads to a dead end: the highlighted color would soon have no room left."
            }
        }
    }
}
