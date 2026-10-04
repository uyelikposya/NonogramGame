import NonogramKit
import SwiftUI

/// Çözülmüş bulmacanın küçük piksel resmi (bölüm ızgarası, sonuç kartı).
@MainActor
struct ArtworkThumbnail: View {
    let artwork: Matrix<RGBColor?>

    var body: some View {
        Canvas { context, size in
            let cell = min(size.width / CGFloat(artwork.columns), size.height / CGFloat(artwork.rows))
            let origin = CGPoint(
                x: (size.width - cell * CGFloat(artwork.columns)) / 2,
                y: (size.height - cell * CGFloat(artwork.rows)) / 2
            )
            for position in artwork.positions {
                guard let color = artwork[position] else { continue }
                // Komşu kareler arasında saç teli boşluk kalmasın diye hafif taşırılır
                let rect = CGRect(
                    x: origin.x + CGFloat(position.column) * cell,
                    y: origin.y + CGFloat(position.row) * cell,
                    width: cell + 0.5,
                    height: cell + 0.5
                )
                context.fill(Path(rect), with: .color(Color(color)))
            }
        }
        .aspectRatio(CGFloat(artwork.columns) / CGFloat(artwork.rows), contentMode: .fit)
        .accessibilityHidden(true)
    }
}
