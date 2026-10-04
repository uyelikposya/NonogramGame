import StoreKit
import SwiftUI

/// "Reklamsız" abonelik ekranı. Fiyat, süre, otomatik yenileme ve iptal bilgisini
/// Apple'ın `SubscriptionStoreView`'ı gösterir; App Store inceleme kurallarına uygundur.
@MainActor
struct AdFreePaywall: View {
    @Environment(StoreManager.self) private var store
    @Environment(\.dismiss) private var dismiss
    @Environment(\.appTheme) private var theme

    var body: some View {
        SubscriptionStoreView(productIDs: StoreManager.productIDs) {
            VStack(spacing: 14) {
                Image("AppLogo")
                    .resizable()
                    .scaledToFit()
                    .frame(width: 84, height: 84)
                    .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
                    .accessibilityHidden(true)
                Text("Catgrid Ad-Free")
                    .font(.title.bold())
                    .foregroundStyle(theme.textPrimary)
                VStack(alignment: .leading, spacing: 10) {
                    benefit("No ads between puzzles", icon: "nosign")
                    benefit("Rewarded ads for extra paws stay optional", icon: "pawprint.fill")
                    benefit("Support new cat breeds and puzzles", icon: "heart.fill")
                }
                .padding(.horizontal, 8)
            }
            .padding(.vertical, 12)
        }
        .storeButton(.visible, for: .restorePurchases)
        .storeButton(.visible, for: .cancellation)
        .subscriptionStorePolicyDestination(url: AppLinks.privacyPolicy, for: .privacyPolicy)
        .subscriptionStorePolicyDestination(url: AppLinks.termsOfUse, for: .termsOfService)
        .onInAppPurchaseCompletion { _, result in
            if case .success(let purchase) = result {
                await store.handlePurchase(purchase)
            }
        }
        .onChange(of: store.isAdsRemoved) { _, removed in
            if removed { dismiss() }
        }
        .tint(theme.accent)
    }

    private func benefit(_ title: LocalizedStringKey, icon: String) -> some View {
        Label {
            Text(title)
                .foregroundStyle(theme.textPrimary)
        } icon: {
            Image(systemName: icon)
                .foregroundStyle(theme.accent)
        }
        .font(.subheadline.weight(.medium))
    }
}
