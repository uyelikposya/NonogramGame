import SwiftUI

/// Bulmaca bitince yukarıdan dökülen konfeti (Dopamin modu). Hep hiyerarşide durur ve
/// dokunmayı engellemez; `start` verilince yaklaşık 2,5 saniye oynar.
@MainActor
struct ConfettiView: View {
    var start: Date?

    private static let duration: TimeInterval = 2.6
    private static let colors: [Color] = [
        Color(hex: "#F7D774"), Color(hex: "#E88680"), Color(hex: "#7FB3D5"),
        Color(hex: "#9BD3AE"), Color(hex: "#C9B6E4"), Color(hex: "#F2C49B"),
    ]

    var body: some View {
        TimelineView(.animation(paused: start == nil)) { timeline in
            Canvas { context, size in
                guard let start else { return }
                let age = timeline.date.timeIntervalSince(start)
                guard age >= 0, age < Self.duration else { return }
                var generator = SeededRandom(seed: UInt64(start.timeIntervalSince1970 * 1000))
                for index in 0..<90 {
                    let x0 = generator.next() * size.width
                    let delay = generator.next() * 0.4
                    let speed = 260 + generator.next() * 260
                    let drift = (generator.next() - 0.5) * 120
                    let spin = (generator.next() - 0.5) * 12
                    let t = max(0, age - delay)
                    let y = -20 + speed * t + 90 * t * t
                    let x = x0 + drift * t + sin(t * 4 + Double(index)) * 14
                    guard y < size.height + 20 else { continue }
                    let fade = min(1, (Self.duration - age) / 0.5)
                    var piece = context
                    piece.translateBy(x: x, y: y)
                    piece.rotate(by: .radians(spin * t))
                    piece.opacity = fade
                    let rect = index % 3 == 0
                        ? CGRect(x: -4, y: -4, width: 8, height: 8)
                        : CGRect(x: -3, y: -6, width: 6, height: 12)
                    let shape = index % 3 == 0 ? Path(ellipseIn: rect) : Path(roundedRect: rect, cornerRadius: 1.5)
                    piece.fill(shape, with: .color(Self.colors[index % Self.colors.count]))
                }
            }
        }
        .allowsHitTesting(false)
        .accessibilityHidden(true)
    }
}

/// Konfetinin her karede aynı dağılımla çizilmesi için basit tohumlu rastgele sayı.
private struct SeededRandom {
    private var state: UInt64

    init(seed: UInt64) {
        state = seed == 0 ? 0x9E3779B97F4A7C15 : seed
    }

    /// 0..<1
    mutating func next() -> Double {
        state = state &* 6364136223846793005 &+ 1442695040888963407
        return Double(state >> 11) / Double(1 << 53)
    }
}
