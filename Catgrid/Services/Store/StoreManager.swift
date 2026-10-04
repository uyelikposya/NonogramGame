import Foundation
import StoreKit

/// "Reklamsız" otomatik yenilenen abonelik (aylık / yıllık), StoreKit 2.
///
/// Abonelik sürdükçe bölümler arası geçiş reklamları gösterilmez; oyuncunun isteğiyle
/// izlenen ödüllü reklam (+1 pati) seçenek olarak kalır. Satın alma ekranı Apple'ın
/// `SubscriptionStoreView`'ıdır (fiyat, süre, yenileme ve iptal bilgisi App Store
/// kurallarına uygun gösterilir).
@MainActor
@Observable
final class StoreManager {
    /// App Store Connect'te aynı abonelik grubunda ("Ad-Free") tanımlanmalı.
    static let monthlyProductID = "com.catgridcollection.nonogram.adfree.monthly"
    static let yearlyProductID = "com.catgridcollection.nonogram.adfree.yearly"
    static let productIDs = [yearlyProductID, monthlyProductID]
    static let cacheKey = "store.adsRemoved"

    /// Son bilinen durum önbellekte tutulur ki uygulama açılır açılmaz (çevrimdışı da) doğru olsun.
    private(set) var isAdsRemoved: Bool {
        didSet { defaults.set(isAdsRemoved, forKey: Self.cacheKey) }
    }

    /// Etkin aboneliğin ürünü (ayarlarda "Aylık"/"Yıllık" göstermek için).
    private(set) var activeProductID: String?
    /// Etkin abonelik yenilenmeyecekse bitiş tarihi.
    private(set) var expirationDate: Date?
    private(set) var willAutoRenew = true

    private let defaults: UserDefaults
    private var updatesTask: Task<Void, Never>?

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
        self.isAdsRemoved = defaults.bool(forKey: Self.cacheKey)
    }

    func start() async {
        guard updatesTask == nil else { return }
        // Yenileme, iptal, iade, başka cihazda satın alma...
        updatesTask = Task { [weak self] in
            for await result in Transaction.updates {
                await self?.handle(result)
            }
        }
        await refreshEntitlements()
    }

    /// `SubscriptionStoreView` satın alma bitirince.
    func handlePurchase(_ result: Product.PurchaseResult) async {
        if case .success(let verification) = result {
            await handle(verification)
        }
    }

    func restorePurchases() async {
        try? await AppStore.sync()
        await refreshEntitlements()
    }

    /// Uygulama öne gelince de çağrılır: süresi dolan abonelik reklamları geri açar.
    func refreshEntitlements() async {
        var active: Transaction?
        for await result in Transaction.currentEntitlements {
            guard case .verified(let transaction) = result,
                  Self.productIDs.contains(transaction.productID),
                  Self.isActive(transaction, now: Date())
            else { continue }
            if active == nil || (transaction.expirationDate ?? .distantFuture) > (active?.expirationDate ?? .distantPast) {
                active = transaction
            }
        }
        isAdsRemoved = active != nil
        activeProductID = active?.productID
        expirationDate = active?.expirationDate
        willAutoRenew = await Self.willAutoRenew(active)
    }

    /// İade edilmemiş ve süresi dolmamış abonelik.
    nonisolated static func isActive(revocationDate: Date?, expirationDate: Date?, now: Date) -> Bool {
        guard revocationDate == nil else { return false }
        guard let expirationDate else { return true }
        return expirationDate > now
    }

    private static func isActive(_ transaction: Transaction, now: Date) -> Bool {
        isActive(revocationDate: transaction.revocationDate, expirationDate: transaction.expirationDate, now: now)
    }

    private static func willAutoRenew(_ transaction: Transaction?) async -> Bool {
        guard let transaction,
              let status = await transaction.subscriptionStatus,
              case .verified(let info) = status.renewalInfo
        else { return true }
        return info.willAutoRenew
    }

    private func handle(_ result: VerificationResult<Transaction>) async {
        guard case .verified(let transaction) = result else { return }
        await transaction.finish()
        await refreshEntitlements()
    }
}
