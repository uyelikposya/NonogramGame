import Foundation

/// Reklam gelir modeli (saf mantık, test edilebilir):
///
/// - Eğitim (Yavru Okulu) bölümlerinde hiç reklam yok.
/// - Kedi türü bulmacalarında her **2** çözümde bir geçiş reklamı; yalnızca oyuncu sonuç
///   kartından ayrılırken (Sonraki Bulmaca / Bölümlere Dön) gösterilir, oyunun ortasında asla.
/// - İki geçiş reklamı arasında en az **90 saniye**: hızlı çözülen küçük bulmacalarda bunaltmaz.
/// - Ödüllü reklam yalnızca isteğe bağlı: canlar bitince "+1 pati" ya da süre bitince "+60 sn".
/// - Premium tanıtımı: ilk kez **2.** geçiş reklamından sonra, ardından her **3** reklamda bir,
///   reklam kapanıp oyuncu yerine geçtikten sonra (reklamın üstüne değil).
final class AdPolicy {
    static let interstitialEvery = 2
    static let minimumInterval: TimeInterval = 90
    static let firstPromoAfter = 2
    static let promoEvery = 3

    private enum Keys {
        static let completions = "ads.completionsSinceInterstitial"
        static let lastShown = "ads.lastInterstitialAt"
        static let sincePromo = "ads.interstitialsSincePromo"
        static let promosShown = "ads.premiumPromosShown"
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

    private(set) var interstitialsSincePromo: Int {
        get { defaults.integer(forKey: Keys.sincePromo) }
        set { defaults.set(newValue, forKey: Keys.sincePromo) }
    }

    private(set) var premiumPromosShown: Int {
        get { defaults.integer(forKey: Keys.promosShown) }
        set { defaults.set(newValue, forKey: Keys.promosShown) }
    }

    func recordInterstitialShown(now: Date = Date()) {
        completionsSinceInterstitial = 0
        lastInterstitialAt = now
        interstitialsSincePromo += 1
    }

    /// Bu reklamdan sonra Premium tanıtımı gösterilmeli mi?
    var isPremiumPromoDue: Bool {
        interstitialsSincePromo >= (premiumPromosShown == 0 ? Self.firstPromoAfter : Self.promoEvery)
    }

    func recordPremiumPromoShown() {
        interstitialsSincePromo = 0
        premiumPromosShown += 1
    }
}
