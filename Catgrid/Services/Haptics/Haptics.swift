import UIKit

/// Titreşimler. SwiftUI'nin `.sensoryFeedback` değiştiricisi yerine UIKit üreteçleri doğrudan
/// kullanılır: olay anında, ayara bakarak tetiklenir ve görünüm ağacına bir şey eklemez.
@MainActor
enum Haptics {
    static var isEnabled: Bool {
        UserDefaults.standard.object(forKey: SettingsKeys.haptics) as? Bool ?? true
    }

    static func play(_ event: GameEvent) {
        guard isEnabled else { return }
        switch event {
        case .mistake, .failed:
            UINotificationFeedbackGenerator().notificationOccurred(.error)
        case .solved:
            UINotificationFeedbackGenerator().notificationOccurred(.success)
        case .lineCompleted:
            UIImpactFeedbackGenerator(style: .light).impactOccurred()
        case .filled, .crossed, .erased:
            break
        }
    }

    static func selection() {
        guard isEnabled else { return }
        UISelectionFeedbackGenerator().selectionChanged()
    }
}
