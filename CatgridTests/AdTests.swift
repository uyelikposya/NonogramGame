import XCTest
@testable import Catgrid

final class AdPolicyTests: XCTestCase {
    func makePolicy() -> AdPolicy {
        AdPolicy(defaults: UserDefaults(suiteName: "AdPolicyTests-\(UUID().uuidString)")!)
    }

    func testTutorialNeverCountsTowardAds() {
        let policy = makePolicy()
        for _ in 0..<10 { policy.registerCompletion(isTutorial: true) }
        XCTAssertFalse(policy.isInterstitialDue())
    }

    func testInterstitialEveryTwoBreedPuzzles() {
        let policy = makePolicy()
        policy.registerCompletion(isTutorial: false)
        XCTAssertFalse(policy.isInterstitialDue())
        policy.registerCompletion(isTutorial: false)
        XCTAssertTrue(policy.isInterstitialDue())

        policy.recordInterstitialShown()
        XCTAssertFalse(policy.isInterstitialDue())
    }

    func testRespectsMinimumIntervalBetweenAds() {
        let policy = makePolicy()
        let start = Date(timeIntervalSinceReferenceDate: 0)
        policy.recordInterstitialShown(now: start)
        policy.registerCompletion(isTutorial: false)
        policy.registerCompletion(isTutorial: false)

        XCTAssertFalse(policy.isInterstitialDue(now: start.addingTimeInterval(30)))
        XCTAssertTrue(policy.isInterstitialDue(now: start.addingTimeInterval(AdPolicy.minimumInterval)))
    }

    func testPremiumPromoAfterSecondAdThenEveryThird() {
        let policy = makePolicy()
        var promoAfter: [Int] = []
        for ad in 1...8 {
            policy.recordInterstitialShown()
            if policy.isPremiumPromoDue {
                promoAfter.append(ad)
                policy.recordPremiumPromoShown()
            }
        }
        XCTAssertEqual(promoAfter, [2, 5, 8])
    }
}

@MainActor
final class AdCoordinatorTests: XCTestCase {
    func testShowsInterstitialOnlyWhenDueThenContinues() async {
        let service = NoAdService()
        let policy = AdPolicy(defaults: UserDefaults(suiteName: "AdCoordinatorTests-\(UUID().uuidString)")!)
        let coordinator = AdCoordinator(service: service, policy: policy)

        var navigations = 0
        coordinator.puzzleCompleted(isTutorial: false)
        coordinator.continueAfterPuzzle { navigations += 1 }
        XCTAssertEqual(navigations, 1)
        XCTAssertEqual(service.interstitialsShown, 0)

        coordinator.puzzleCompleted(isTutorial: false)
        let shown = expectation(description: "reklam sonrası devam")
        coordinator.continueAfterPuzzle {
            navigations += 1
            shown.fulfill()
        }
        await fulfillment(of: [shown], timeout: 2)
        XCTAssertEqual(navigations, 2)
        XCTAssertEqual(service.interstitialsShown, 1)
        XCTAssertFalse(coordinator.isPremiumPromoPresented, "İlk reklamdan sonra tanıtım yok")
    }

    func testPremiumPromoOpensAfterSecondAd() async {
        let service = NoAdService()
        let policy = AdPolicy(defaults: UserDefaults(suiteName: "Promo-\(UUID().uuidString)")!)
        var clock = Date(timeIntervalSinceReferenceDate: 0)
        let coordinator = AdCoordinator(service: service, policy: policy, now: { clock })

        for round in 1...2 {
            coordinator.puzzleCompleted(isTutorial: false)
            coordinator.puzzleCompleted(isTutorial: false)
            let done = expectation(description: "reklam \(round)")
            coordinator.continueAfterPuzzle { done.fulfill() }
            await fulfillment(of: [done], timeout: 2)
            clock.addTimeInterval(AdPolicy.minimumInterval)
        }
        // Tanıtım, devam eyleminden hemen sonra açılır
        try? await Task.sleep(for: .milliseconds(50))
        XCTAssertEqual(service.interstitialsShown, 2)
        XCTAssertTrue(coordinator.isPremiumPromoPresented)
    }
}

@MainActor
final class RemoveAdsTests: XCTestCase {
    func testPurchasedRemoveAdsSkipsInterstitials() async {
        let service = NoAdService()
        let policy = AdPolicy(defaults: UserDefaults(suiteName: "RemoveAds-\(UUID().uuidString)")!)
        let coordinator = AdCoordinator(service: service, policy: policy)
        coordinator.interstitialsDisabled = true

        for _ in 0..<4 { coordinator.puzzleCompleted(isTutorial: false) }
        var navigated = false
        coordinator.continueAfterPuzzle { navigated = true }

        XCTAssertTrue(navigated, "Reklam olmadan hemen devam edilmeli")
        XCTAssertEqual(service.interstitialsShown, 0)
    }

    func testSubscriptionActiveUntilExpiration() {
        let now = Date()
        XCTAssertTrue(StoreManager.isActive(revocationDate: nil, expirationDate: now.addingTimeInterval(60), now: now))
        XCTAssertFalse(StoreManager.isActive(revocationDate: nil, expirationDate: now.addingTimeInterval(-60), now: now))
        XCTAssertFalse(StoreManager.isActive(revocationDate: now, expirationDate: now.addingTimeInterval(60), now: now))
    }

    @MainActor
    func testCachedSubscriptionStateIsRestoredOnLaunch() throws {
        let defaults = try XCTUnwrap(UserDefaults(suiteName: "Store-\(UUID().uuidString)"))
        XCTAssertFalse(StoreManager(defaults: defaults).isPremium)
        defaults.set(true, forKey: StoreManager.cacheKey)
        XCTAssertTrue(StoreManager(defaults: defaults).isPremium)
    }

    func testSubscriptionProductsAreConfiguredLocally() throws {
        // Simülatörde satın alma denemesi için .storekit dosyasında iki abonelik olmalı
        let url = URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent().deletingLastPathComponent()
            .appendingPathComponent("Catgrid/Resources/Catgrid.storekit")
        let text = try String(contentsOf: url)
        for id in StoreManager.productIDs {
            XCTAssertTrue(text.contains(id), "\(id) .storekit dosyasında yok")
        }
    }
}

@MainActor
final class AudioManagerTests: XCTestCase {
    func testPersistsSoundSettings() {
        let defaults = UserDefaults(suiteName: "AudioManagerTests-\(UUID().uuidString)")!
        let audio = AudioManager(defaults: defaults)
        XCTAssertTrue(audio.musicEnabled)
        XCTAssertTrue(audio.effectsEnabled)

        audio.musicEnabled = false
        audio.effectsVolume = 0.25

        let reloaded = AudioManager(defaults: defaults)
        XCTAssertFalse(reloaded.musicEnabled)
        XCTAssertEqual(reloaded.effectsVolume, 0.25)
    }

    func testBundlesEverySoundFile() {
        for effect in SoundEffect.allCases {
            XCTAssertNotNil(Bundle.main.url(forResource: effect.rawValue, withExtension: "wav"), effect.rawValue)
        }
        XCTAssertNotNil(Bundle.main.url(forResource: "music_cozy", withExtension: "m4a"))
    }
}
