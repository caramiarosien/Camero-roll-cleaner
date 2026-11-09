import SwiftUI
import SwiftData

@main
struct YolkApp: App {
    init() {
        FontRegistrar.registerBundledFonts()
    }

    var body: some Scene {
        WindowGroup {
            RootView()
                .tint(Theme.royal)
        }
        .modelContainer(for: [Decision.self])
    }
}
