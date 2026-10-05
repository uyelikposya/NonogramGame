import NonogramKit
import SwiftUI

/// Çözülmüş bulmacanın küçük piksel resmi (bölüm ızgarası, rozetler, kartlar, sonuç).
///
/// Açık renkli şekiller (krem, açık gri) açık zeminde kaybolmasın diye silüetin dış
/// kenarına ince bir kontur çizilir. Kontur rengi temanın metin rengidir: açık temada
/// koyu, koyu temada açık; böylece şekil her zeminde ayırt edilir (HIG: metin dışı
/// grafiklerde yeterli kontrast, yalnızca renge güvenmeme).
@MainActor
struct ArtworkThumbnail: View {
    @Environment(\.appTheme) private var theme
    let artwork: Matrix<RGBColor?>
    var outlined = true

    var body: some View {
        let artwork = artwork
        let outline = outlined ? theme.textPrimary.opacity(0.7) : nil
        Canvas { context, size in
            // Kontur kenardan taşmasın diye çizim alanı biraz içeride
            let line = outline == nil ? 0 : min(max(min(size.width, size.height) / 50, 1), 2)
            let inset = line
            let cell = min(
                (size.width - inset * 2) / CGFloat(artwork.columns),
                (size.height - inset * 2) / CGFloat(artwork.rows)
            )
            let origin = CGPoint(
                x: (size.width - cell * CGFloat(artwork.columns)) / 2,
                y: (size.height - cell * CGFloat(artwork.rows)) / 2
            )
            func isFilled(_ row: Int, _ column: Int) -> Bool {
                row >= 0 && column >= 0 && row < artwork.rows && column < artwork.columns && artwork[row, column] != nil
            }

            var edges = Path()
            for position in artwork.positions {
                guard let color = artwork[position] else { continue }
                let x = origin.x + CGFloat(position.column) * cell
                let y = origin.y + CGFloat(position.row) * cell
                // Komşu kareler arasında saç teli boşluk kalmasın diye hafif taşırılır
                context.fill(Path(CGRect(x: x, y: y, width: cell + 0.5, height: cell + 0.5)), with: .color(Color(color)))

                guard outline != nil else { continue }
                let (row, column) = (position.row, position.column)
                if !isFilled(row - 1, column) { edges.move(to: CGPoint(x: x, y: y)); edges.addLine(to: CGPoint(x: x + cell, y: y)) }
                if !isFilled(row + 1, column) { edges.move(to: CGPoint(x: x, y: y + cell)); edges.addLine(to: CGPoint(x: x + cell, y: y + cell)) }
                if !isFilled(row, column - 1) { edges.move(to: CGPoint(x: x, y: y)); edges.addLine(to: CGPoint(x: x, y: y + cell)) }
                if !isFilled(row, column + 1) { edges.move(to: CGPoint(x: x + cell, y: y)); edges.addLine(to: CGPoint(x: x + cell, y: y + cell)) }
            }
            if let outline {
                context.stroke(edges, with: .color(outline), style: StrokeStyle(lineWidth: line, lineCap: .square, lineJoin: .miter))
            }
        }
        .aspectRatio(CGFloat(artwork.columns) / CGFloat(artwork.rows), contentMode: .fit)
        .accessibilityHidden(true)
    }
}
