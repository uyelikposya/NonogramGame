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
