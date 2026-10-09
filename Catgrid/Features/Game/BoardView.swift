import NonogramKit
import SwiftUI

/// Tamamlanan satır/sütunun parıltısı (Dopamin modu).
struct LineGlow: Equatable {
    static let duration: TimeInterval = 0.6
    var row: Int?
    var column: Int?
    var start: Date
}

/// İpuçları + tahta. Kareler tek bir `Canvas` ile çizilir; 20x20'de 400 ayrı View yerine
/// tek çizim, sürüklemede akıcı kalır.
@MainActor
struct BoardView: View {
    @Environment(\.appTheme) private var theme
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    let game: NonogramGame
    var activeCell: GridPosition?
    /// Kısa süreliğine kırmızı yanıp sönen hatalı kare.
    var flashingCell: GridPosition?
    /// Kedinin "şuna bak" dediği satır ya da sütun.
    var hint: HintFinder.Hint?
    /// Eğitimde dokunulacak kareyi gösteren pati.
    var pointer: GridPosition?
    /// Dopamin modu: az önce tamamlanan satır/sütunun kısa parıltısı.
    var lineGlow: LineGlow?
    let onDragBegan: (GridPosition) -> Void
    let onDragMoved: (GridPosition) -> Void
    let onDragEnded: () -> Void

    @State private var isDragging = false

    private var puzzle: Puzzle { game.puzzle }
    private var isSolved: Bool { game.status == .won }

    var body: some View {
        GeometryReader { proxy in
            let rowClueSlots = max(puzzle.rowClues.map(\.count).max() ?? 1, 1)
            let columnClueSlots = max(puzzle.columnClues.map(\.count).max() ?? 1, 1)
            let cell = max(floor(min(
                proxy.size.width / CGFloat(puzzle.columns + rowClueSlots),
                proxy.size.height / CGFloat(puzzle.rows + columnClueSlots)
            )), 1)

            VStack(alignment: .leading, spacing: 0) {
                HStack(alignment: .bottom, spacing: 0) {
                    Color.clear.frame(width: cell * CGFloat(rowClueSlots), height: cell * CGFloat(columnClueSlots))
                    ForEach(0..<puzzle.columns, id: \.self) { column in
                        VStack(spacing: 0) {
                            ForEach(clueTexts(puzzle.columnClues[column]), id: \.self) { text in
                                clueLabel(text, size: cell)
                            }
                        }
                        .frame(width: cell)
                        .background(clueBackground(isActive: activeCell?.column == column, isHinted: isHinted(.column, column)))
                        .foregroundStyle(clueColor(isSatisfied: game.isColumnSatisfied(column)))
                    }
                }
                HStack(alignment: .top, spacing: 0) {
                    VStack(alignment: .trailing, spacing: 0) {
                        ForEach(0..<puzzle.rows, id: \.self) { row in
                            HStack(spacing: 0) {
                                ForEach(clueTexts(puzzle.rowClues[row]), id: \.self) { text in
                                    clueLabel(text, size: cell)
                                }
                            }
                            .frame(width: cell * CGFloat(rowClueSlots), height: cell, alignment: .trailing)
                            .background(clueBackground(isActive: activeCell?.row == row, isHinted: isHinted(.row, row)))
                            .foregroundStyle(clueColor(isSatisfied: game.isRowSatisfied(row)))
                        }
                    }
                    board(cell: cell)
                }
            }
            .opacity(isSolved ? 0 : 1)
            .overlay {
                // Çözülünce tahta kaybolur, yerine kedi resmi büyüyerek gelir.
                // Resim hep hiyerarşide durur, yalnızca görünürlüğü değişir: dokunma alanının
                // altında görünüm eklenip çıkarılması iOS 17'de dokunma sistemini bozabiliyor.
                ArtworkThumbnail(artwork: puzzle.artwork)
                    .padding(12)
                    // Beyaz kediler açık zeminde kaybolmasın
                    .background(RoundedRectangle(cornerRadius: 16).fill(theme.surfaceMuted))
                    .padding(4)
                    .scaleEffect(isSolved || reduceMotion ? 1 : 0.6)
                    .opacity(isSolved ? 1 : 0)
                    .allowsHitTesting(false)
            }
            .animation(.spring(duration: 0.7), value: isSolved)
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
    }

    // MARK: - Tahta

    private func board(cell: CGFloat) -> some View {
        let board = game.board
        let theme = theme
        let activeCell = activeCell
        let flashingCell = flashingCell
        let hint = hint
        let lineGlow = lineGlow

        // Parıltı yalnızca varken zaman çizelgesi işler; yoksa duraklar
        return TimelineView(.animation(paused: lineGlow == nil)) { timeline in
        Canvas { context, size in
            context.fill(Path(CGRect(origin: .zero, size: size)), with: .color(theme.surface))

            if let active = activeCell {
                let rowRect = CGRect(x: 0, y: CGFloat(active.row) * cell, width: size.width, height: cell)
                let columnRect = CGRect(x: CGFloat(active.column) * cell, y: 0, width: cell, height: size.height)
                context.fill(Path(rowRect), with: .color(theme.highlight))
                context.fill(Path(columnRect), with: .color(theme.highlight))
            }

            for position in board.positions {
                let rect = CGRect(
                    x: CGFloat(position.column) * cell,
                    y: CGFloat(position.row) * cell,
                    width: cell,
                    height: cell
                )
                switch board[position] {
                case .filled:
                    let inset = rect.insetBy(dx: cell * 0.06, dy: cell * 0.06)
                    context.fill(Path(roundedRect: inset, cornerRadius: cell * 0.16), with: .color(theme.cellFilled))
                case .crossed:
                    var cross = Path()
                    let inset = rect.insetBy(dx: cell * 0.3, dy: cell * 0.3)
                    cross.move(to: inset.origin)
                    cross.addLine(to: CGPoint(x: inset.maxX, y: inset.maxY))
                    cross.move(to: CGPoint(x: inset.maxX, y: inset.minY))
                    cross.addLine(to: CGPoint(x: inset.minX, y: inset.maxY))
                    context.stroke(
                        cross,
                        with: .color(theme.cellCross),
                        style: StrokeStyle(lineWidth: max(cell * 0.07, 1.2), lineCap: .round)
                    )
                case .blank:
                    break
                }
            }
            // Hatalı kare de Canvas içinde çizilir (ayrı görünüm eklenmez)
            if let flashing = flashingCell {
                let rect = CGRect(
                    x: CGFloat(flashing.column) * cell,
                    y: CGFloat(flashing.row) * cell,
                    width: cell,
                    height: cell
                )
                context.fill(Path(roundedRect: rect, cornerRadius: cell * 0.16), with: .color(theme.mistake.opacity(0.55)))
            }
            Self.drawGridLines(in: context, size: size, cell: cell, rows: board.rows, columns: board.columns, theme: theme)
            // İpucu çizgisi en üstte, kalın bir çerçeveyle
            if let hint {
                let rect = hint.axis == .row
                    ? CGRect(x: 0, y: CGFloat(hint.index) * cell, width: size.width, height: cell)
                    : CGRect(x: CGFloat(hint.index) * cell, y: 0, width: cell, height: size.height)
                let frame = Path(roundedRect: rect.insetBy(dx: 1.5, dy: 1.5), cornerRadius: cell * 0.2)
                context.fill(frame, with: .color(theme.accent.opacity(0.12)))
                context.stroke(frame, with: .color(theme.accent), lineWidth: 3)
            }
            if let glow = lineGlow {
                let age = timeline.date.timeIntervalSince(glow.start)
                if age >= 0, age < LineGlow.duration {
                    let fade = 1 - age / LineGlow.duration
                    var rects: [CGRect] = []
                    if let row = glow.row { rects.append(CGRect(x: 0, y: CGFloat(row) * cell, width: size.width, height: cell)) }
                    if let column = glow.column { rects.append(CGRect(x: CGFloat(column) * cell, y: 0, width: cell, height: size.height)) }
                    for rect in rects {
                        // Satır boyunca soldan sağa (sütunda yukarıdan aşağı) kayan ışık
                        let sweep = age / LineGlow.duration
                        let path = Path(roundedRect: rect.insetBy(dx: 1, dy: 1), cornerRadius: cell * 0.2)
                        context.fill(path, with: .color(Gold.bright.opacity(0.35 * fade)))
                        context.stroke(path, with: .color(Gold.mid.opacity(fade)), lineWidth: 3)
                        let spot = rect.width > rect.height
                            ? CGPoint(x: rect.minX + rect.width * sweep, y: rect.midY)
                            : CGPoint(x: rect.midX, y: rect.minY + rect.height * sweep)
                        let radius = cell * 0.45
                        context.fill(Path(ellipseIn: CGRect(x: spot.x - radius, y: spot.y - radius, width: radius * 2, height: radius * 2)),
                                     with: .color(.white.opacity(0.7 * fade)))
                    }
                }
            }
        }
        }
        .frame(width: cell * CGFloat(board.columns), height: cell * CGFloat(board.rows))
        .clipShape(RoundedRectangle(cornerRadius: 6))
        // Pati hep hiyerarşide durur (yalnızca görünürlüğü değişir); dokunmayı engellemez
        .overlay(alignment: .topLeading) {
            PawPointer()
                .offset(
                    x: CGFloat(pointer?.column ?? 0) * cell + cell * 0.45,
                    y: CGFloat(pointer?.row ?? 0) * cell + cell * 0.5
                )
                .opacity(pointer == nil ? 0 : 1)
        }
        .contentShape(Rectangle())
        .gesture(dragGesture(cell: cell))
        .accessibilityElement()
        .accessibilityLabel(Text("Puzzle board"))
        .accessibilityIdentifier("game.board")
        .accessibilityValue(Text(game.progress, format: .percent.precision(.fractionLength(0))))
    }

    /// Her 5 karede bir kalın çizgi: büyük tahtalarda saymayı kolaylaştırır.
    private static func drawGridLines(
        in context: GraphicsContext,
        size: CGSize,
        cell: CGFloat,
        rows: Int,
        columns: Int,
        theme: AppTheme
    ) {
        func stroke(from start: CGPoint, to end: CGPoint, major: Bool) {
            var line = Path()
            line.move(to: start)
            line.addLine(to: end)
            context.stroke(line, with: .color(major ? theme.gridLineMajor : theme.gridLine), lineWidth: major ? 1.5 : 0.75)
        }
        // Önce ince, sonra kalın çizgiler: kesişimlerde kalın olan üstte kalsın
        for major in [false, true] {
            for index in 0...columns where (index % 5 == 0 || index == columns) == major {
                let x = CGFloat(index) * cell
                stroke(from: CGPoint(x: x, y: 0), to: CGPoint(x: x, y: size.height), major: major)
            }
            for index in 0...rows where (index % 5 == 0 || index == rows) == major {
                let y = CGFloat(index) * cell
                stroke(from: CGPoint(x: 0, y: y), to: CGPoint(x: size.width, y: y), major: major)
            }
        }
    }

    /// Dokunma da sıfır mesafeli sürükleme olarak işlenir, böylece tek bir yol kalır.
    private func dragGesture(cell: CGFloat) -> some Gesture {
        DragGesture(minimumDistance: 0)
            .onChanged { value in
                guard value.location.x >= 0, value.location.y >= 0 else { return }
                let position = GridPosition(row: Int(value.location.y / cell), column: Int(value.location.x / cell))
                if isDragging {
                    onDragMoved(position)
                } else {
                    isDragging = true
                    onDragBegan(position)
                }
            }
            .onEnded { _ in
                isDragging = false
                onDragEnded()
            }
    }

    // MARK: - İpuçları

    private func clueColor(isSatisfied: Bool) -> Color {
        isSatisfied ? theme.textSecondary.opacity(0.45) : theme.textPrimary
    }

    private func clueBackground(isActive: Bool, isHinted: Bool) -> some View {
        RoundedRectangle(cornerRadius: 4)
            .fill(isHinted ? theme.accent.opacity(0.3) : (isActive ? theme.highlight : .clear))
    }

    private func isHinted(_ axis: HintFinder.Axis, _ index: Int) -> Bool {
        hint?.axis == axis && hint?.index == index
    }

    /// Aynı sayı tekrar edebildiği için konumla birlikte benzersiz kimlik üretilir.
    private func clueTexts(_ clue: [Int]) -> [String] {
        let numbers = clue.isEmpty ? [0] : clue
        return numbers.enumerated().map { "\($0.offset):\($0.element)" }
    }

    private func clueLabel(_ text: String, size: CGFloat) -> some View {
        Text(verbatim: String(text.split(separator: ":").last ?? ""))
            .font(.system(size: min(size * 0.5, 22), weight: .semibold, design: .rounded))
            .monospacedDigit()
            .minimumScaleFactor(0.6)
            .frame(width: size, height: size)
    }
}
