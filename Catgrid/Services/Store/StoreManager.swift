import Foundation
import StoreKit

/// "Reklamları Kaldır" tek seferlik satın alması (StoreKit 2).
///
/// Bölümler arası geçiş reklamlarını kapatır; oyuncunun isteğiyle izlenen ödüllü reklam
/// (+1 pati) seçenek olarak kalır. Satın alma Apple hesabına bağlıdır, geri yüklenebilir.
@MainActor
@Observable
final class StoreManager {
    static let removeAdsProductID = "com.catgridcollection.nonogram.removeads"
    static let cacheKey = "store.adsRemoved"

    private(set) var removeAdsProduct: Product?
    private(set) var isPurchasing = false
    /// Son bilinen durum önbellekte tutulur ki uygulama açılır açılmaz (çevrimdışı da) doğru olsun.
    private(set) var isAdsRemoved: Bool {
        didSet { defaults.set(isAdsRemoved, forKey: Self.cacheKey) }
    }

    private let defaults: UserDefaults
    private var updatesTask: Task<Void, Never>?

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
        self.isAdsRemoved = defaults.bool(forKey: Self.cacheKey)
    }

    func start() async {
        guard updatesTask == nil else { return }
        // Başka cihazda yapılan satın alma, iade vb.
        updatesTask = Task { [weak self] in
            for await result in Transaction.updates {
                await self?.handle(result)
            }
        }
        await refreshEntitlements()
        removeAdsProduct = try? await Product.products(for: [Self.removeAdsProductID]).first
    }

    func purchaseRemoveAds() async {
        guard let product = removeAdsProduct, !isPurchasing else { return }
        isPurchasing = true
        defer { isPurchasing = false }
        do {
            if case .success(let verification) = try await product.purchase() {
                await handle(verification)
            }
        } catch {
            // Kullanıcı iptali ve ağ hataları sessizce geçilir; düğme tekrar denenebilir.
        }
    }

    func restorePurchases() async {
        try? await AppStore.sync()
        await refreshEntitlements()
    }

    private func refreshEntitlements() async {
        var owned = false
        for await result in Transaction.currentEntitlements {
            if case .verified(let transaction) = result,
               transaction.productID == Self.removeAdsProductID,
               transaction.revocationDate == nil {
                owned = true
            }
        }
        isAdsRemoved = owned
    }

    private func handle(_ result: VerificationResult<Transaction>) async {
        guard case .verified(let transaction) = result else { return }
        if transaction.productID == Self.removeAdsProductID {
            isAdsRemoved = transaction.revocationDate == nil
        }
        await transaction.finish()
    }
}
