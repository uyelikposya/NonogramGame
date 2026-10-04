import Foundation

/// Reklam gelir modeli (saf mantık, test edilebilir):
///
/// - Eğitim (Yavru Okulu) bölümlerinde hiç reklam yok.
/// - Kedi türü bulmacalarında her **2** çözümde bir geçiş reklamı; yalnızca oyuncu sonuç
///   kartından ayrılırken (Sonraki Bulmaca / Bölümlere Dön) gösterilir, oyunun ortasında asla.
/// - İki geçiş reklamı arasında en az **90 saniye**: hızlı çözülen küçük bulmacalarda bunaltmaz.
/// - Ödüllü reklam yalnızca isteğe bağlı: canlar bitince "+1 pati" ya da süre bitince "+60 sn".
final class AdPolicy {
    static let interstitialEvery = 2
    static let minimumInterval: TimeInterval = 90

    private enum Keys {
        static let completions = "ads.completionsSinceInterstitial"
        static let lastShown = "ads.lastInterstitialAt"
    }

    private let defaults: UserDefaults

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
    }

    private(set) var completionsSinceInterstitial: Int {
        get { defaults.integer(forKey: Keys.completions) }
        set { defaults.set(newValue, forKey: Keys.completions) }
    }

    private(set) var lastInterstitialAt: Date? {
        get { defaults.object(forKey: Keys.lastShown) as? Date }
        set { defaults.set(newValue, forKey: Keys.lastShown) }
    }

    func registerCompletion(isTutorial: Bool) {
        guard !isTutorial else { return }
        completionsSinceInterstitial += 1
    }

    func isInterstitialDue(now: Date = Date()) -> Bool {
        guard completionsSinceInterstitial >= Self.interstitialEvery else { return false }
        guard let last = lastInterstitialAt else { return true }
        return now.timeIntervalSince(last) >= Self.minimumInterval
    }

    func recordInterstitialShown(now: Date = Date()) {
        completionsSinceInterstitial = 0
        lastInterstitialAt = now
    }
}
