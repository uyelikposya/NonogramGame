import SwiftUI

@MainActor
struct RootView: View {
    @Environment(Router.self) private var router
    @Environment(ThemeManager.self) private var themeManager
    @Environment(\.colorScheme) private var colorScheme

    var body: some View {
        @Bindable var router = router
        NavigationStack(path: $router.path) {
            HomeView()
                .navigationDestination(for: Route.self) { route in
                    switch route {
                    case .chapters: ChaptersView()
                    case .chapter(let id): ChapterView(chapterID: id)
                    case .game(let puzzleID): GameScreen(puzzleID: puzzleID)
                    case .settings: SettingsView()
                    case .stats: StatsView()
                    }
                }
        }
        // appChrome temayı okuduğu için environment'ın içinde kalmalı
        .appChrome()
        .environment(\.appTheme, themeManager.theme(for: colorScheme))
        .onAppear { themeManager.applyInterfaceStyle() }
    }
}
