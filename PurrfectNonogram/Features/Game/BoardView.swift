import NonogramKit
import SwiftUI

/// İpuçları + tahta. Kareler tek bir `Canvas` ile çizilir; 20x20'de 400 ayrı View yerine
/// tek çizim, sürüklemede akıcı kalır.
struct BoardView: View {
    let game: NonogramGame
    let onDragBegan: (GridPosition) -> Void
    let onDragMoved: (GridPosition) -> Void
    let onDragEnded: () -> Void

    @State private var isDragging = false

    private var puzzle: Puzzle { game.puzzle }

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
                        .opacity(game.isColumnSatisfied(column) ? 0.35 : 1)
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
                            .opacity(game.isRowSatisfied(row) ? 0.35 : 1)
                        }
                    }
                    grid(cell: cell)
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
    }

    // MARK: - Tahta

    private func grid(cell: CGFloat) -> some View {
        let board = game.board
        let artwork = puzzle.artwork
        let showArtwork = game.status == .won

        return Canvas { context, size in
            for position in board.positions {
                let rect = CGRect(
                    x: CGFloat(position.column) * cell,
                    y: CGFloat(position.row) * cell,
                    width: cell,
                    height: cell
                )
                if showArtwork {
                    if let color = artwork[position] { context.fill(Path(rect), with: .color(Color(color))) }
                    continue
                }
                switch board[position] {
                case .filled:
                    context.fill(Path(rect.insetBy(dx: 1, dy: 1)), with: .color(.primary))
                case .crossed:
                    var cross = Path()
                    let inset = rect.insetBy(dx: cell * 0.28, dy: cell * 0.28)
                    cross.move(to: inset.origin)
                    cross.addLine(to: CGPoint(x: inset.maxX, y: inset.maxY))
                    cross.move(to: CGPoint(x: inset.maxX, y: inset.minY))
                    cross.addLine(to: CGPoint(x: inset.minX, y: inset.maxY))
                    context.stroke(cross, with: .color(.secondary), lineWidth: 1.5)
                case .blank:
                    break
                }
            }
            guard !showArtwork else { return }
            drawGridLines(in: context, size: size, cell: cell, rows: board.rows, columns: board.columns)
        }
        .frame(width: cell * CGFloat(board.columns), height: cell * CGFloat(board.rows))
        .contentShape(Rectangle())
        .gesture(dragGesture(cell: cell))
        .animation(.easeInOut(duration: 0.6), value: showArtwork)
    }

    /// Her 5 karede bir kalın çizgi: büyük tahtalarda saymayı kolaylaştırır.
    private func drawGridLines(in context: GraphicsContext, size: CGSize, cell: CGFloat, rows: Int, columns: Int) {
        for index in 0...columns {
            let x = CGFloat(index) * cell
            var line = Path()
            line.move(to: CGPoint(x: x, y: 0))
            line.addLine(to: CGPoint(x: x, y: size.height))
            context.stroke(line, with: .color(.secondary.opacity(0.6)), lineWidth: index % 5 == 0 ? 1.5 : 0.5)
        }
        for index in 0...rows {
            let y = CGFloat(index) * cell
            var line = Path()
            line.move(to: CGPoint(x: 0, y: y))
            line.addLine(to: CGPoint(x: size.width, y: y))
            context.stroke(line, with: .color(.secondary.opacity(0.6)), lineWidth: index % 5 == 0 ? 1.5 : 0.5)
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

    /// Aynı sayı tekrar edebildiği için konumla birlikte benzersiz kimlik üretilir.
    private func clueTexts(_ clue: [Int]) -> [String] {
        let numbers = clue.isEmpty ? [0] : clue
        return numbers.enumerated().map { "\($0.offset):\($0.element)" }
    }

    private func clueLabel(_ text: String, size: CGFloat) -> some View {
        Text(verbatim: String(text.split(separator: ":").last ?? ""))
            .font(.system(size: size * 0.5, weight: .semibold, design: .rounded))
            .monospacedDigit()
            .frame(width: size, height: size)
    }
}

extension Color {
    init(_ color: RGBColor) {
        self.init(red: Double(color.red) / 255, green: Double(color.green) / 255, blue: Double(color.blue) / 255)
    }
}
