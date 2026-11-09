import SwiftUI

struct RootView: View {
    @StateObject private var library = PhotoLibrary.shared

    var body: some View {
        ZStack {
            Theme.background.ignoresSafeArea()
            DisplayHeadline(lead: "Weniger ", accent: "Ballast.", trail: "\nMehr Platz.")
                .padding(24)
        }
    }
}
