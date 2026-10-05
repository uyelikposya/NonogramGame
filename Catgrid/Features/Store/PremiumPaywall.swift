import StoreKit
import SwiftUI

/// "Catgrid Premium" abonelik ekranı. Fiyat, süre, otomatik yenileme ve iptal bilgisini
/// Apple'ın `SubscriptionStoreView`'ı gösterir; App Store inceleme kurallarına uygundur.
///
/// Ayarlardan, ana sayfa bannerından, bölüm ekranındaki altın bulmaca tanıtımından ve
/// birkaç geçiş reklamından sonra tanıtım olarak açılır.
@MainActor
struct PremiumPaywall: View {
    @Environment(StoreManager.self) private var store
    @Environment(\.dismiss) private var dismiss
    @Environment(\.appTheme) private var theme
    /// Reklamlardan sonra kendiliğinden açıldıysa başlık farklı.
    var isPromo = false

    var body: some View {
        SubscriptionStoreView(productIDs: StoreManager.productIDs) {
            VStack(spacing: 14) {
                ZStack(alignment: .top) {
                    Image("AppLogo")
                        .resizable()
                        .scaledToFit()
                        .frame(width: 84, height: 84)
                        .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
                        .overlay(
                            RoundedRectangle(cornerRadius: 20, style: .continuous)
                                .strokeBorder(Gold.foil, lineWidth: 3)
                        )
                        .padding(.top, 16)
                    Image(systemName: "crown.fill")
                        .font(.title2)
                        .foregroundStyle(Gold.foil)
                        .shadow(color: Gold.deep.opacity(0.4), radius: 2, y: 1)
                }
                .accessibilityHidden(true)

                VStack(spacing: 4) {
                    if isPromo {
                        Text("Enjoying Catgrid?")
                            .font(.headline)
                            .foregroundStyle(theme.textSecondary)
                    }
                    Text(verbatim: "Catgrid Premium")
                        .font(.title.bold())
                        .foregroundStyle(theme.textPrimary)
                }

                VStack(alignment: .leading, spacing: 10) {
                    benefit("No ads between puzzles", icon: "nosign")
                    benefit("9 golden puzzles for every breed", icon: "crown.fill")
                    benefit("Collect shiny Golden Cards", icon: "rectangle.stack.fill")
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
        .onChange(of: store.isPremium) { _, isPremium in
            if isPremium { dismiss() }
        }
        .tint(Gold.deep)
    }

    private func benefit(_ title: LocalizedStringKey, icon: String) -> some View {
        Label {
            Text(title)
                .foregroundStyle(theme.textPrimary)
        } icon: {
            Image(systemName: icon)
                .foregroundStyle(Gold.deep)
        }
        .font(.subheadline.weight(.medium))
    }
}

/// Ana sayfadaki "Premium'a geç" bannerı (yalnızca abone olmayanlara).
@MainActor
struct PremiumBanner: View {
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 12) {
                Image(systemName: "crown.fill")
                    .font(.title3)
                    .foregroundStyle(Gold.ink)
                    .frame(width: 40, height: 40)
                    .background(Circle().fill(Gold.light.opacity(0.7)))
                VStack(alignment: .leading, spacing: 2) {
                    Text("Go Premium")
                        .font(.headline)
                    Text("No ads · Golden puzzles · Golden Cards")
                        .font(.caption)
                        .lineLimit(1)
                        .minimumScaleFactor(0.8)
                }
                .foregroundStyle(Gold.ink)
                Spacer(minLength: 4)
                Image(systemName: "chevron.right")
                    .font(.subheadline.bold())
                    .foregroundStyle(Gold.ink.opacity(0.7))
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 10)
            .background(RoundedRectangle(cornerRadius: 18, style: .continuous).fill(Gold.foil))
            .overlay(
                RoundedRectangle(cornerRadius: 18, style: .continuous)
                    .strokeBorder(Gold.deep.opacity(0.5), lineWidth: 1)
            )
            .shadow(color: Gold.deep.opacity(0.25), radius: 8, y: 3)
        }
        .buttonStyle(PressableButtonStyle())
        .accessibilityIdentifier("home.premiumBanner")
    }
}
