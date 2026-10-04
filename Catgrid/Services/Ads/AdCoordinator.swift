import Foundation

/// Ekranların reklamla tek temas noktası: politikayı uygular, reklam ağını saklar.
@MainActor
@Observable
final class AdCoordinator {
    private let service: any AdService
    private let policy: AdPolicy
    private let now: () -> Date

    init(service: any AdService, policy: AdPolicy = AdPolicy(), now: @escaping () -> Date = { Date() }) {
        self.service = service
        self.policy = policy
        self.now = now
    }

    static func live() -> AdCoordinator {
        #if canImport(GoogleMobileAds)
        return AdCoordinator(service: GoogleAdService())
        #else
        return AdCoordinator(service: NoAdService())
        #endif
    }

    var isRewardedReady: Bool { service.isRewardedReady }
    var isPrivacyOptionsRequired: Bool { service.isPrivacyOptionsRequired }

    func start() async {
        await service.start()
    }

    func puzzleCompleted(isTutorial: Bool) {
        policy.registerCompletion(isTutorial: isTutorial)
    }

    /// Sonuç kartından ayrılırken çağrılır: sırası geldiyse önce geçiş reklamı, sonra `action`.
    func continueAfterPuzzle(_ action: @escaping () -> Void) {
        guard policy.isInterstitialDue(now: now()) else {
            action()
            return
        }
        Task {
            if await service.showInterstitial() {
                policy.recordInterstitialShown(now: now())
            }
            action()
        }
    }

    /// Ödüllü reklam: oyuncu sonuna kadar izlediyse `true`.
    func watchRewardedAd() async -> Bool {
        await service.showRewarded()
    }

    func presentPrivacyOptions() async {
        await service.presentPrivacyOptions()
    }
}
