#if canImport(GoogleMobileAds)
import AppTrackingTransparency
import GoogleMobileAds
import UIKit
import UserMessagingPlatform

/// Google Mobile Ads 11.x (Xcode 15 uyumlu son sürüm) ile geçiş ve ödüllü reklamlar.
@MainActor
@Observable
final class GoogleAdService: NSObject, AdService {
    private(set) var isRewardedReady = false
    private(set) var isPrivacyOptionsRequired = false

    private let configuration: AdConfiguration
    private var interstitial: GADInterstitialAd?
    private var rewarded: GADRewardedAd?
    private var isStarted = false
    private var dismissContinuation: CheckedContinuation<Void, Never>?

    init(configuration: AdConfiguration = .current) {
        self.configuration = configuration
    }

    func start() async {
        guard !isStarted else { return }
        isStarted = true
        await requestConsent()
        await requestTrackingAuthorization()
        guard UMPConsentInformation.sharedInstance.canRequestAds else { return }
        await withCheckedContinuation { continuation in
            GADMobileAds.sharedInstance().start { _ in continuation.resume() }
        }
        loadInterstitial()
        loadRewarded()
    }

    // MARK: - Onay ve izleme izni

    private func requestConsent() async {
        let parameters = UMPRequestParameters()
        let consent = UMPConsentInformation.sharedInstance
        await withCheckedContinuation { (continuation: CheckedContinuation<Void, Never>) in
            consent.requestConsentInfoUpdate(with: parameters) { _ in continuation.resume() }
        }
        if let root = UIApplication.shared.topViewController {
            await withCheckedContinuation { (continuation: CheckedContinuation<Void, Never>) in
                UMPConsentForm.loadAndPresentIfRequired(from: root) { _ in continuation.resume() }
            }
        }
        isPrivacyOptionsRequired = consent.privacyOptionsRequirementStatus == .required
    }

    private func requestTrackingAuthorization() async {
        guard ATTrackingManager.trackingAuthorizationStatus == .notDetermined else { return }
        _ = await withCheckedContinuation { continuation in
            ATTrackingManager.requestTrackingAuthorization { continuation.resume(returning: $0) }
        }
    }

    func presentPrivacyOptions() async {
        guard let root = UIApplication.shared.topViewController else { return }
        await withCheckedContinuation { (continuation: CheckedContinuation<Void, Never>) in
            UMPConsentForm.presentPrivacyOptionsForm(from: root) { _ in continuation.resume() }
        }
    }

    // MARK: - Yükleme

    private func loadInterstitial() {
        GADInterstitialAd.load(withAdUnitID: configuration.interstitialUnitID, request: GADRequest()) { [weak self] ad, _ in
            Task { @MainActor in
                self?.interstitial = ad
                ad?.fullScreenContentDelegate = self
            }
        }
    }

    private func loadRewarded() {
        GADRewardedAd.load(withAdUnitID: configuration.rewardedUnitID, request: GADRequest()) { [weak self] ad, _ in
            Task { @MainActor in
                self?.rewarded = ad
                ad?.fullScreenContentDelegate = self
                self?.isRewardedReady = ad != nil
            }
        }
    }

    // MARK: - Gösterme

    func showInterstitial() async -> Bool {
        guard let ad = interstitial, let root = UIApplication.shared.topViewController else {
            if isStarted, interstitial == nil { loadInterstitial() }
            return false
        }
        interstitial = nil
        await withCheckedContinuation { (continuation: CheckedContinuation<Void, Never>) in
            dismissContinuation = continuation
            ad.present(fromRootViewController: root)
        }
        loadInterstitial()
        return true
    }

    func showRewarded() async -> Bool {
        guard let ad = rewarded, let root = UIApplication.shared.topViewController else { return false }
        rewarded = nil
        isRewardedReady = false
        var earned = false
        await withCheckedContinuation { (continuation: CheckedContinuation<Void, Never>) in
            dismissContinuation = continuation
            ad.present(fromRootViewController: root) { earned = true }
        }
        loadRewarded()
        return earned
    }

    fileprivate func finishPresentation() {
        dismissContinuation?.resume()
        dismissContinuation = nil
    }
}

extension GoogleAdService: GADFullScreenContentDelegate {
    nonisolated func adDidDismissFullScreenContent(_ ad: GADFullScreenPresentingAd) {
        Task { @MainActor in self.finishPresentation() }
    }

    nonisolated func ad(_ ad: GADFullScreenPresentingAd, didFailToPresentFullScreenContentWithError error: Error) {
        Task { @MainActor in self.finishPresentation() }
    }
}
#endif

import UIKit

extension UIApplication {
    /// Reklam ve onay formlarının sunulacağı en üstteki ekran.
    var topViewController: UIViewController? {
        let window = connectedScenes
            .compactMap { $0 as? UIWindowScene }
            .flatMap(\.windows)
            .first { $0.isKeyWindow }
        var top = window?.rootViewController
        while let presented = top?.presentedViewController {
            top = presented
        }
        return top
    }
}
