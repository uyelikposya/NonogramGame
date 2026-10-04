import SwiftUI

@MainActor
struct RootView: View {
    @Environment(Router.self) private var router
    @Environment(ThemeManager.self) private var themeManager
    @Environment(AudioManager.self) private var audio
    @Environment(AdCoordinator.self) private var ads
    @Environment(\.colorScheme) private var colorScheme
    @Environment(\.scenePhase) private var scenePhase

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
        .onAppear {
            themeManager.applyInterfaceStyle()
            audio.prepare()
            audio.startMusic()
        }
        // Onay formu, izleme izni ve reklam SDK'sı; ekran çizildikten sonra
        .task { await ads.start() }
        .onChange(of: scenePhase) { _, phase in
            if phase == .active {
                audio.resumeMusic()
            } else if phase == .background {
                audio.pauseMusic()
            }
        }
    }
}
