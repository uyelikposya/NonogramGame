import SwiftUI

@main
@MainActor
struct CatgridApp: App {
    @State private var model = AppModel.live()
    @State private var themeManager = ThemeManager()
    @State private var router = Router()
    @State private var audio = AudioManager()
    @State private var ads = AdCoordinator.live()
    @State private var store = StoreManager()

    var body: some Scene {
        WindowGroup {
            RootView()
                .environment(model)
                .environment(themeManager)
                .environment(router)
                .environment(audio)
                .environment(ads)
                .environment(store)
        }
    }
}
