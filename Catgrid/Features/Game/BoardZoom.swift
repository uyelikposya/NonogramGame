import SwiftUI
import UIKit

/// Büyük tahtalarda yakınlaştırma durumu. Kaydırma görünümü günceller; ipucu şeritleri okur.
/// Ayrı bir nesne olduğu için kaydırırken yalnızca şeritler yeniden çizilir, tahta değil.
@MainActor
@Observable
final class BoardZoom {
    /// Tahta bu ölçekte çizilir; en uzak görünümde 1/maxScale ile küçültülür (yakınlaşınca net kalır).
    static let maxScale: CGFloat = 3

    /// Ekrandaki ölçek: 1 tahtanın sığdığı hal, en fazla `maxScale`.
    var scale: CGFloat = 1
    /// Ekran noktasında kaydırma miktarı.
    var offset: CGPoint = .zero

    @ObservationIgnored weak var scrollView: UIScrollView?

    var isZoomed: Bool { scale > 1.05 }

    func reset() {
        guard let scrollView else { return }
        scrollView.setZoomScale(scrollView.minimumZoomScale, animated: true)
    }
}

/// Yakınlaştırılan tahtayla birlikte kayan ipucu şeridi (satırlarda dikey, sütunlarda yatay).
@MainActor
struct PannedStrip<Content: View>: View {
    let zoom: BoardZoom
    let axis: Axis
    let fitCell: CGFloat
    @ViewBuilder let content: (CGFloat) -> Content

    var body: some View {
        content(fitCell * zoom.scale)
            .fixedSize()
            .offset(x: axis == .horizontal ? -zoom.offset.x : 0, y: axis == .vertical ? -zoom.offset.y : 0)
            .allowsHitTesting(false)
    }
}

/// Yakınlaşınca beliren "küçült" düğmesi. Hep hiyerarşide durur (yalnızca görünürlüğü değişir).
@MainActor
struct ZoomResetButton: View {
    @Environment(\.appTheme) private var theme
    let zoom: BoardZoom

    var body: some View {
        Button {
            zoom.reset()
        } label: {
            Image(systemName: "arrow.down.right.and.arrow.up.left")
                .font(.footnote.weight(.bold))
                .frame(width: 32, height: 32)
                .background(Circle().fill(theme.surface.opacity(0.92)))
                .foregroundStyle(theme.textPrimary)
                .shadow(color: .black.opacity(0.15), radius: 3, y: 1)
        }
        .buttonStyle(PressableButtonStyle())
        .opacity(zoom.isZoomed ? 1 : 0)
        .allowsHitTesting(zoom.isZoomed)
        .accessibilityLabel(Text("Zoom out"))
        .accessibilityHidden(!zoom.isZoomed)
    }
}

/// İki parmakla yakınlaştırılıp kaydırılan tahta. Tek parmak dokunuşları doğrudan tahtaya gider
/// (kaydırma iki parmak ister), böylece kaydırırken yanlışlıkla kare boyanmaz.
struct ZoomableBoard<Content: View>: UIViewRepresentable {
    let zoom: BoardZoom
    /// Tahtanın sığdığı haldeki boyutu.
    let fitSize: CGSize
    @ViewBuilder let content: () -> Content

    func makeCoordinator() -> Coordinator {
        Coordinator(zoom: zoom, hosting: UIHostingController(rootView: content()))
    }

    func makeUIView(context: Context) -> UIScrollView {
        let scrollView = UIScrollView()
        scrollView.delegate = context.coordinator
        scrollView.panGestureRecognizer.minimumNumberOfTouches = 2
        scrollView.delaysContentTouches = false
        scrollView.showsHorizontalScrollIndicator = false
        scrollView.showsVerticalScrollIndicator = false
        scrollView.contentInsetAdjustmentBehavior = .never
        scrollView.backgroundColor = .clear
        scrollView.clipsToBounds = true
        scrollView.layer.cornerRadius = 6
        let hosting = context.coordinator.hosting
        hosting.view.backgroundColor = .clear
        hosting.safeAreaRegions = []
        scrollView.addSubview(hosting.view)
        zoom.scrollView = scrollView
        configure(scrollView, coordinator: context.coordinator)
        return scrollView
    }

    func updateUIView(_ scrollView: UIScrollView, context: Context) {
        context.coordinator.hosting.rootView = content()
        configure(scrollView, coordinator: context.coordinator)
    }

    private func configure(_ scrollView: UIScrollView, coordinator: Coordinator) {
        let full = CGSize(width: fitSize.width * BoardZoom.maxScale, height: fitSize.height * BoardZoom.maxScale)
        guard coordinator.contentSize != full, full.width > 0, full.height > 0 else { return }
        coordinator.contentSize = full
        // Boyut değişince (döndürme, ilk açılış) tahta yeniden sığdırılır
        scrollView.minimumZoomScale = 1 / BoardZoom.maxScale
        scrollView.maximumZoomScale = 1
        scrollView.zoomScale = 1
        coordinator.hosting.view.frame = CGRect(origin: .zero, size: full)
        scrollView.contentSize = full
        scrollView.zoomScale = scrollView.minimumZoomScale
        scrollView.contentOffset = .zero
    }

    @MainActor
    final class Coordinator: NSObject, UIScrollViewDelegate {
        let zoom: BoardZoom
        let hosting: UIHostingController<Content>
        var contentSize: CGSize = .zero

        init(zoom: BoardZoom, hosting: UIHostingController<Content>) {
            self.zoom = zoom
            self.hosting = hosting
        }

        func viewForZooming(in scrollView: UIScrollView) -> UIView? {
            hosting.view
        }

        func scrollViewDidZoom(_ scrollView: UIScrollView) {
            publish(scrollView)
        }

        func scrollViewDidScroll(_ scrollView: UIScrollView) {
            publish(scrollView)
        }

        /// Görünüm güncellenirken durum değiştirmemek için bir sonraki turda yayınlanır.
        private func publish(_ scrollView: UIScrollView) {
            let scale = scrollView.zoomScale * BoardZoom.maxScale
            let offset = scrollView.contentOffset
            let zoom = zoom
            Task { @MainActor in
                if abs(zoom.scale - scale) > 0.001 { zoom.scale = scale }
                if zoom.offset != offset { zoom.offset = offset }
            }
        }
    }
}
