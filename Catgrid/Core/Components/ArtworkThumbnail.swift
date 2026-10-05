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
    /// Altın Kart: resim parlaklığına göre altın tonlarıyla (heykel gibi) çizilir.
    var goldTone = false

    var body: some View {
        let artwork = artwork
        let outline = outlined ? (goldTone ? Gold.dark : theme.textPrimary.opacity(0.7)) : nil
        let goldTone = goldTone
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
                let fill = goldTone ? Self.gold(for: color) : Color(color)
                context.fill(Path(CGRect(x: x, y: y, width: cell + 0.5, height: cell + 0.5)), with: .color(fill))

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

    /// Rengin parlaklığını koyu bronzdan açık altına uzanan bir rampaya eşler; ayrıntılar
    /// (göz, burun) parlaklık farkıyla seçilir kalır.
    nonisolated static func gold(for color: RGBColor) -> Color {
        let luminance = (0.299 * Double(color.red) + 0.587 * Double(color.green) + 0.114 * Double(color.blue)) / 255
        let t = min(max((luminance - 0.08) / 0.84, 0), 1)
        let stops: [(Double, Double, Double)] = [(0.36, 0.22, 0.04), (0.75, 0.53, 0.12), (0.97, 0.80, 0.33), (1.0, 0.95, 0.74)]
        let position = t * Double(stops.count - 1)
        let index = min(Int(position), stops.count - 2)
        let f = position - Double(index)
        let (a, b) = (stops[index], stops[index + 1])
        return Color(red: a.0 + (b.0 - a.0) * f, green: a.1 + (b.1 - a.1) * f, blue: a.2 + (b.2 - a.2) * f)
    }
}
