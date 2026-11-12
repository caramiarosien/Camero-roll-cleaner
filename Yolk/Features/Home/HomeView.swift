import SwiftData
import SwiftUI

/// Startbildschirm: Überschrift, Speicher-Zähler, Papierkorb und die Aufräum-Modi als Bildkacheln.
struct HomeView: View {
    @EnvironmentObject private var library: PhotoLibrary
    @Environment(\.modelContext) private var context
    @Query(filter: #Predicate<Decision> { $0.kindRaw == "trash" }) private var trashed: [Decision]
    @AppStorage(StatsKey.freedBytes) private var freedBytes: Int = 0

    @State private var preview: [MediaItem] = []
    @State private var remaining = 0
    @StateObject private var navigator = Navigator()
    /// Nur neu laden, wenn der Startbildschirm zu sehen ist, nicht bei jedem Wisch im Hintergrund.
    @State private var isVisible = false

    var body: some View {
        let trashCount = trashed.count
        let trashBytes = trashed.reduce(Int64(0)) { $0 + $1.byteSize }

        NavigationStack(path: $navigator.path) {
            ScrollView {
                VStack(alignment: .leading, spacing: 0) {
                    BrandMark()
                        .padding(.top, 8)

                    DisplayHeadline(lead: "Weniger ", accent: "Ballast.", trail: "\nMehr Platz.", size: 46)
                        .padding(.top, 22)

                    statCard
                        .padding(.top, 20)

                    if trashCount > 0 {
                        Button { navigator.open(.trash) } label: { trashCard(count: trashCount, bytes: trashBytes) }
                            .buttonStyle(.plain)
                            .padding(.top, 10)
                    }

                    SectionLabel(text: "Aufräumen")
                        .padding(.top, 30)
                        .padding(.bottom, 12)

                    LazyVGrid(columns: [GridItem(.flexible(), spacing: 14), GridItem(.flexible(), spacing: 14)], spacing: 20) {
                        NavigationLink(value: Route.swipe) {
                            ModeTile(title: "Alle Fotos", subtitle: "\(remaining.formatted()) übrig", items: preview)
                        }
                        .buttonStyle(.plain)

                        ModeTile(title: "Screenshots", subtitle: "Bald", items: [], enabled: false)
                        ModeTile(title: "Ähnliche", subtitle: "Bald", items: [], enabled: false)
                        ModeTile(title: "Videos", subtitle: "Bald", items: [], enabled: false)
                        ModeTile(title: "Nach Monat", subtitle: "Bald", items: [], enabled: false)
                    }
                }
                .padding(.horizontal, 22)
                .padding(.bottom, 32)
            }
            .background(Theme.background.ignoresSafeArea())
            .toolbar(.hidden, for: .navigationBar)
            // Einziges Navigationsziel der App. Der Papierkorb bleibt offen, auch wenn er leer wird.
            .navigationDestination(for: Route.self) { route in
                switch route {
                case .swipe: SwipeView()
                case .trash: TrashView()
                }
            }
            .onAppear {
                isVisible = true
                reload()
            }
            .onDisappear { isVisible = false }
            .onChange(of: library.changeToken) { _, _ in if isVisible { reload() } }
        }
        .environmentObject(navigator)
        #if DEBUG
        .task { DebugLaunch.apply(context: context, library: library, navigator: navigator) }
        #endif
    }

    private func reload() {
        let decided = Set(((try? context.fetch(FetchDescriptor<Decision>())) ?? []).map(\.assetID))
        remaining = max(0, library.totalCount() - decided.count)
        preview = library.newestItems(excluding: decided, limit: 4)
    }

    private var statCard: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack(alignment: .firstTextBaseline, spacing: 8) {
                Text(Formatting.bytes(Int64(freedBytes)))
                    .font(.display(30))
                    .foregroundStyle(Theme.ink)
                Text("schon freigeräumt")
                    .font(.system(size: 13))
                    .foregroundStyle(Theme.inkSecondary)
            }
            if freedBytes > 0 {
                Text("Wird frei, sobald „Zuletzt gelöscht“ geleert ist.")
                    .font(.system(size: 12))
                    .foregroundStyle(Theme.inkSecondary)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, 16)
        .padding(.vertical, 14)
        .background(Theme.surface, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: 16, style: .continuous).stroke(Theme.line, lineWidth: 1))
    }

    private func trashCard(count: Int, bytes: Int64) -> some View {
        HStack(spacing: 12) {
            Image(systemName: "trash")
                .font(.system(size: 16))
                .foregroundStyle(Theme.royal)
                .frame(width: 36, height: 36)
                .background(Theme.royalSoft, in: Circle())
            VStack(alignment: .leading, spacing: 2) {
                Text("Papierkorb")
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundStyle(Theme.ink)
                Text("\(Formatting.photos(count)) · \(Formatting.bytes(bytes))")
                    .font(.system(size: 13))
                    .foregroundStyle(Theme.inkSecondary)
            }
            Spacer()
            Image(systemName: "chevron.right")
                .font(.system(size: 13, weight: .semibold))
                .foregroundStyle(Theme.inkSecondary)
        }
        .padding(12)
        .background(Theme.surface, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: 16, style: .continuous).stroke(Theme.line, lineWidth: 1))
        .accessibilityElement(children: .combine)
    }
}

/// Kachel mit 2×2 Vorschaubildern, Titel und Unterzeile.
struct ModeTile: View {
    let title: String
    let subtitle: String
    let items: [MediaItem]
    var enabled = true

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            GeometryReader { geo in
                let side = (geo.size.width - 2) / 2
                LazyVGrid(columns: [GridItem(.fixed(side), spacing: 2), GridItem(.fixed(side), spacing: 2)], spacing: 2) {
                    ForEach(0..<4, id: \.self) { index in
                        if index < items.count {
                            AssetImageView(item: items[index], targetSize: CGSize(width: side, height: side))
                                .frame(width: side, height: side)
                                .clipped()
                        } else {
                            Rectangle()
                                .fill(Color(hex: [0xECEDEF, 0xE1E3E7, 0xF3F3F5, 0xE6E8EB][index]))
                                .frame(width: side, height: side)
                        }
                    }
                }
            }
            .aspectRatio(1, contentMode: .fit)
            .clipShape(RoundedRectangle(cornerRadius: Theme.tileRadius, style: .continuous))

            Text(title)
                .font(.system(size: 14, weight: .semibold))
                .foregroundStyle(Theme.ink)
                .padding(.top, 8)
            Text(subtitle)
                .font(.system(size: 13))
                .foregroundStyle(Theme.inkSecondary)
        }
        .opacity(enabled ? 1 : 0.5)
        .accessibilityElement(children: .combine)
    }
}
