import SwiftUI

struct RootView: View {
    @StateObject private var library = PhotoLibrary.shared
    @Environment(\.scenePhase) private var scenePhase
    /// Bei eingeschränktem Zugriff kann Gary bewusst trotzdem weitermachen.
    @AppStorage("continueWithLimitedAccess") private var continueWithLimited = false

    var body: some View {
        Group {
            switch library.access {
            case .authorized:
                HomeView()
            case .limited where continueWithLimited:
                HomeView()
            default:
                PermissionView(continueWithLimited: $continueWithLimited)
            }
        }
        .environmentObject(library)
        .onChange(of: scenePhase) { _, phase in
            if phase == .active { library.refreshAccess() }
        }
    }
}
