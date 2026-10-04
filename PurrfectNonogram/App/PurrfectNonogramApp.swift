import SwiftUI

@main
@MainActor
struct PurrfectNonogramApp: App {
    @State private var model = AppModel.live()
    @State private var themeManager = ThemeManager()
    @State private var router = Router()

    var body: some Scene {
        WindowGroup {
            RootView()
                .environment(model)
                .environment(themeManager)
                .environment(router)
        }
    }
}
