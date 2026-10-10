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
                .overlay(alignment: .top) {
                    // Seri sözü tahtanın üstünde büyük
                    if let combo = effects.last(where: { if case .combo = $0.kind { true } else { false } }),
                       case .combo(let count) = combo.kind {
                        ComboWord(count: count)
                            .id(combo.id)
                            .offset(y: -18)
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
        let game = game
        let level = game.level
        let theme = theme
        let activeCell = activeCell
        let wrongCell = wrongCell
        let hint = hint
        let focus = Set(hint?.focus ?? [])
        let targets = Set(hint?.cells ?? [])
        let portraits = Dictionary(uniqueKeysWithValues: (0..<level.size).compactMap { region -> (Int, Image)? in
            guard let chapter = cats.breed(level.breeds[region]), let image = PortraitImages.image(for: chapter) else { return nil }
            return (region, image)
        })
        return Canvas { context, size in
            context.fill(Path(roundedRect: CGRect(origin: .zero, size: size), cornerRadius: 12), with: .color(theme.surface))
            let gap = max(cell * 0.06, 1.5)
            for row in 0..<level.size {
                for column in 0..<level.size {
                    let position = GridPosition(row: row, column: column)
                    let region = level.region(at: position)
                    let rect = CGRect(x: CGFloat(column) * cell, y: CGFloat(row) * cell, width: cell, height: cell)
                        .insetBy(dx: gap / 2, dy: gap / 2)
                    let tile = Path(roundedRect: rect, cornerRadius: cell * 0.14)
                    let mark = game[position]
                    var color = CatPalette.color(region)
                    if mark == .wrong { color = theme.mistake }
                    context.fill(tile, with: .color(color))
                    if position == activeCell {
                        context.fill(tile, with: .color(.white.opacity(0.25)))
                    }
                    switch mark {
                    case .cross, .wrong:
                        var cross = Path()
                        let inset = rect.insetBy(dx: cell * 0.27, dy: cell * 0.27)
                        cross.move(to: inset.origin)
                        cross.addLine(to: CGPoint(x: inset.maxX, y: inset.maxY))
                        cross.move(to: CGPoint(x: inset.maxX, y: inset.minY))
                        cross.addLine(to: CGPoint(x: inset.minX, y: inset.maxY))
                        context.stroke(cross, with: .color(.white), style: StrokeStyle(lineWidth: max(cell * 0.1, 2), lineCap: .round))
                    case .cat:
                        context.fill(tile, with: .color(.white.opacity(0.35)))
                        if let image = portraits[region] {
                            context.draw(image, in: rect.insetBy(dx: cell * 0.08, dy: cell * 0.08))
                        }
                    case .blank:
                        break
                    }
                    if position == wrongCell {
                        context.stroke(tile, with: .color(.white), lineWidth: 3)
                    }
                    // İpucu önizlemesi: nedeni gösteren kareler aydınlık, diğerleri karartılır;
                    // X konacak kareler kesik çizgili çerçeve ve soluk X ile
                    if hint != nil {
                        if !focus.contains(position), !targets.contains(position) {
                            context.fill(tile, with: .color(.black.opacity(0.45)))
                        }
                        if targets.contains(position) {
                            context.stroke(tile, with: .color(.white), style: StrokeStyle(lineWidth: 2.5, dash: [5, 4]))
                            if case .onlySpot = hint?.kind {
                                context.fill(Path(ellipseIn: rect.insetBy(dx: cell * 0.3, dy: cell * 0.3)), with: .color(.white.opacity(0.85)))
                            } else if mark == .blank {
                                var cross = Path()
                                let inset = rect.insetBy(dx: cell * 0.3, dy: cell * 0.3)
                                cross.move(to: inset.origin)
                                cross.addLine(to: CGPoint(x: inset.maxX, y: inset.maxY))
                                cross.move(to: CGPoint(x: inset.maxX, y: inset.minY))
                                cross.addLine(to: CGPoint(x: inset.minX, y: inset.maxY))
                                context.stroke(cross, with: .color(.white.opacity(0.6)), style: StrokeStyle(lineWidth: max(cell * 0.08, 1.5), lineCap: .round))
                            }
                        }
                    }
                }
            }
        }
    }
}

/// Türlerin piksel portreleri bir kez resme çevrilip saklanır (tahtada hızlı çizim için).
@MainActor
enum PortraitImages {
    private static var cache: [String: Image] = [:]

    static func image(for chapter: Chapter) -> Image? {
        if let image = cache[chapter.id] { return image }
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
        case .points: -16
        case .found: 14
        case .perfectlyMarked: 34
        case .combo: 0
        }
    }

    @ViewBuilder
    private var label: some View {
        switch effect.kind {
        case .points(let points):
            Text(verbatim: "+\(points)")
                .foregroundStyle(Color(red: 1, green: 0.78, blue: 0.3))
        case .found:
            Text("Found!")
        case .perfectlyMarked:
            Text("Perfectly marked!")
                .foregroundStyle(Color(red: 1, green: 0.9, blue: 0.4))
        case .combo:
            EmptyView()
        }
    }
}

/// Seri sözü: "Güzel", "Harika", "Mükemmel"…
@MainActor
struct ComboWord: View {
    let count: Int
    @State private var shown = false

    var body: some View {
        word
            .font(.system(size: 30, weight: .black, design: .rounded))
            .foregroundStyle(
                LinearGradient(colors: colors, startPoint: .top, endPoint: .bottom)
            )
            .shadow(color: .black.opacity(0.3), radius: 3, y: 2)
            .scaleEffect(shown ? 1 : 0.4)
            .opacity(shown ? 1 : 0)
            .task {
                withAnimation(.spring(response: 0.3, dampingFraction: 0.5)) { shown = true }
                try? await Task.sleep(for: .seconds(1.0))
                withAnimation(.easeIn(duration: 0.3)) { shown = false }
            }
    }

    private var colors: [Color] {
        switch count {
        case 2: [Color(red: 0.5, green: 0.85, blue: 1), Color(red: 0.2, green: 0.55, blue: 0.95)]
        case 3: [Color(red: 0.6, green: 0.95, blue: 0.6), Color(red: 0.2, green: 0.7, blue: 0.35)]
        case 4: [Color(red: 0.4, green: 0.9, blue: 1), Color(red: 0.1, green: 0.5, blue: 0.9)]
        case 5: [Color(red: 1, green: 0.85, blue: 0.4), Color(red: 1, green: 0.55, blue: 0.1)]
        default: [Color(red: 1, green: 0.6, blue: 0.9), Color(red: 0.75, green: 0.3, blue: 0.95)]
        }
    }

    @ViewBuilder
    private var word: some View {
        switch count {
        case 2: Text("Nice")
        case 3: Text("Great")
        case 4: Text("Perfect")
        case 5: Text("Excellent")
        case 6: Text("Amazing")
        default: Text("Unstoppable!")
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
