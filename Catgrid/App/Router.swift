import SwiftUI

enum Route: Hashable {
    case chapters
    case chapter(id: String)
    case game(puzzleID: String)
    case settings
    case stats
    case collection
}

/// Uygulama içi gezinme yığını. Ekranlar doğrudan `NavigationLink` yerine bunu kullanır
/// ki "Sonraki Bulmaca" gibi akışlar yığını kontrollü değiştirebilsin.
@MainActor
@Observable
final class Router {
    var path: [Route] = []

    func push(_ route: Route) {
        path.append(route)
    }

    /// En üstteki ekranı değiştirir (ör. oyun → sonraki oyun); geri tuşu bir önceki listeye döner.
    func replaceTop(with route: Route) {
        if !path.isEmpty { path.removeLast() }
        path.append(route)
    }

    func pop() {
        if !path.isEmpty { path.removeLast() }
    }
}
