import NonogramKit
import SwiftUI

/// Büyük tahtalarda imleç: GameView durumu ve eylemleri buradan tahtaya verir.
struct BoardCursorControls {
    var position: GridPosition
    var lockedTool: MarkTool?
    let onMark: (MarkTool) -> Void
    let onLock: (MarkTool) -> Void
    let onUnlock: () -> Void
    let onMove: (GridPosition) -> Void
}

/// İmlecin yanında duran panel: Doldur, X ve taşıma.
/// - Doldur/X'e dokun: imlecin karesi işaretlenir (ya da silinir).
/// - Doldur/X'e basılı tutup sağa kaydır: araç kilitlenir; imleç hareket ettikçe geçtiği
///   kareler işaretlenir ve imleç yalnızca o satırda ya da sütunda ilerler.
///   Kilitli düğmeye tekrar dokununca imleç serbest kalır.
/// - Taşıma düğmesini sürükle: imleç parmağın yönünde kare kare ilerler.
@MainActor
struct CursorPad: View {
    @Environment(\.appTheme) private var theme
    let controls: BoardCursorControls
    let cell: CGFloat
    let rows: Int
    let columns: Int

    @State private var moveOrigin: GridPosition?
    @State private var slidingTool: MarkTool?
    @State private var slideOffset: CGFloat = 0

    static let width: CGFloat = 54
    static let buttonHeight: CGFloat = 54
    /// Kilitlemek için sağa kaydırma mesafesi.
    private static let lockDistance: CGFloat = 28

    private var height: CGFloat { Self.buttonHeight * 3 }
    private static let ink = Color(red: 0.36, green: 0.40, blue: 0.54)

    var body: some View {
        VStack(spacing: 0) {
            toolButton(.fill, systemImage: "square.fill", label: "Fill")
            divider
            toolButton(.cross, systemImage: "xmark", label: "Cross")
            divider
            moveButton
        }
        .frame(width: Self.width, height: height)
        .background(Capsule().fill(Self.ink.opacity(0.94)))
        .clipShape(Capsule())
        .overlay(alignment: .trailing) { lockHint }
        .shadow(color: .black.opacity(0.25), radius: 6, y: 3)
        .offset(placement)
        .animation(.snappy(duration: 0.16), value: controls.position)
    }

    private var divider: some View {
        Rectangle()
            .fill(.white.opacity(0.25))
            .frame(height: 1)
            .padding(.horizontal, 6)
    }

    /// İmlecin sağında (yer yoksa solunda), satırına ortalanmış; tahtanın dışına taşmaz.
    private var placement: CGSize {
        let boardWidth = cell * CGFloat(columns)
        let boardHeight = cell * CGFloat(rows)
        let position = controls.position
        let gap = max(cell * 0.6, 6)
        var x = CGFloat(position.column + 1) * cell + gap
        if x + Self.width > boardWidth {
            x = CGFloat(position.column) * cell - gap - Self.width
        }
        x = min(max(x, 0), max(boardWidth - Self.width, 0))
        let centerY = (CGFloat(position.row) + 0.5) * cell
        let y = min(max(centerY - height / 2, 0), max(boardHeight - height, 0))
        return CGSize(width: x, height: y)
    }

    private func toolButton(_ tool: MarkTool, systemImage: String, label: LocalizedStringKey) -> some View {
        let isLocked = controls.lockedTool == tool
        return ZStack {
            Rectangle()
                .fill(isLocked ? theme.accent : .clear)
            Image(systemName: systemImage)
                .font(.system(size: 24, weight: .bold))
                .foregroundStyle(.white)
            Image(systemName: "lock.fill")
                .font(.system(size: 10, weight: .bold))
                .foregroundStyle(.white)
                .offset(x: 15, y: 15)
                .opacity(isLocked ? 1 : 0)
        }
        .frame(width: Self.width, height: Self.buttonHeight)
        .contentShape(Rectangle())
        .offset(x: slidingTool == tool ? slideOffset : 0)
        .gesture(
            DragGesture(minimumDistance: 0)
                .onChanged { value in
                    slidingTool = tool
                    slideOffset = min(max(value.translation.width, 0), Self.lockDistance + 10)
                }
                .onEnded { value in
                    let translation = value.translation
                    withAnimation(.snappy(duration: 0.15)) {
                        slidingTool = nil
                        slideOffset = 0
                    }
                    if translation.width >= Self.lockDistance {
                        Haptics.selection()
                        controls.onLock(tool)
                    } else if hypot(translation.width, translation.height) < 14 {
                        if isLocked {
                            Haptics.selection()
                            controls.onUnlock()
                        } else {
                            controls.onMark(tool)
                        }
                    }
                }
        )
        .accessibilityElement()
        .accessibilityLabel(Text(label))
        .accessibilityValue(isLocked ? Text("Locked") : Text(verbatim: ""))
        .accessibilityAddTraits(.isButton)
        .accessibilityAction { controls.onMark(tool) }
        .accessibilityAction(named: Text("Lock")) { controls.onLock(tool) }
    }

    /// Sağa kaydırırken beliren kilit: "bırakırsan kilitlenir".
    private var lockHint: some View {
        Image(systemName: "lock.fill")
            .font(.system(size: 14, weight: .bold))
            .foregroundStyle(.white)
            .padding(7)
            .background(Circle().fill(theme.accent))
            .offset(x: 30, y: slidingTool == .cross ? 0 : -Self.buttonHeight)
            .opacity(slidingTool == nil ? 0 : min(slideOffset / Self.lockDistance, 1))
            .allowsHitTesting(false)
    }

    private var moveButton: some View {
        Image(systemName: "arrow.up.and.down.and.arrow.left.and.right")
            .font(.system(size: 22, weight: .bold))
            .foregroundStyle(.white)
            .frame(width: Self.width, height: Self.buttonHeight)
            .contentShape(Rectangle())
            // Panel imleçle birlikte kaydığı için ölçüm ekran koordinatlarında yapılır
            .gesture(
                DragGesture(minimumDistance: 0, coordinateSpace: .global)
                    .onChanged { value in
                        let origin = moveOrigin ?? controls.position
                        if moveOrigin == nil { moveOrigin = origin }
                        let step = max(cell, 26)
                        let target = GridPosition(
                            row: origin.row + Int((value.translation.height / step).rounded()),
                            column: origin.column + Int((value.translation.width / step).rounded())
                        )
                        controls.onMove(target)
                    }
                    .onEnded { _ in moveOrigin = nil }
            )
            .accessibilityLabel(Text("Move cursor"))
            .accessibilityAdjustableAction { direction in
                let position = controls.position
                switch direction {
                case .increment: controls.onMove(GridPosition(row: position.row, column: position.column + 1))
                case .decrement: controls.onMove(GridPosition(row: position.row, column: position.column - 1))
                @unknown default: break
                }
            }
    }
}
