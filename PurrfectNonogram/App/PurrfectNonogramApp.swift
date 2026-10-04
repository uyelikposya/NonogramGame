import SwiftUI

@main
@MainActor
struct PurrfectNonogramApp: App {
    @State private var model = AppModel.live()

    var body: some Scene {
        WindowGroup {
            NavigationStack {
                LevelListView()
            }
            .environment(model)
        }
    }
}
