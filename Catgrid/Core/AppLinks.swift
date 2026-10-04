import Foundation

/// App Store'un istediği bağlantılar. Sayfalar `docs/` klasöründe; GitHub Pages
/// açıldığında bu adreslerde yayınlanır. Kendi alan adına taşırsan yalnızca burayı değiştir.
enum AppLinks {
    static let privacyPolicy = URL(string: "https://uyelikposya.github.io/NonogramGame/privacy.html")!
    static let support = URL(string: "https://uyelikposya.github.io/NonogramGame/support.html")!
    /// Apple'ın standart kullanım koşulları (EULA); abonelikli uygulamalarda bağlantı zorunlu.
    static let termsOfUse = URL(string: "https://www.apple.com/legal/internet-services/itunes/dev/stdeula/")!
}
