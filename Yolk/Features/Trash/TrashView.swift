import SwiftData
import SwiftUI

/// Papierkorb: alle Links-Wischer, einmal prüfen, einmal bestätigen.
struct TrashView: View {
    @EnvironmentObject private var library: PhotoLibrary
    @Environment(\.modelContext) private var context
    @Environment(\.dismiss) private var dismiss
    @Query(filter: #Predicate<Decision> { $0.kindRaw == "trash" }, sort: \Decision.decidedAt, order: .reverse)
    private var trashed: [Decision]
    @AppStorage(StatsKey.freedBytes) private var freedBytes: Int = 0

    @State private var items: [MediaItem] = []
    @State private var isDeleting = false
    @State private var errorMessage: String?
    @State private var result: DeleteResult?
    /// IDs eines Löschauftrags, der in die Zeitgrenze lief. PhotoKit kann ihn danach noch ausführen.
    @State private var pendingIDs: Set<String> = []
    /// Fotos, die iOS nicht löschen ließ (z. B. aus geteilten Alben).
    @State private var undeletable: [MediaItem] = []

    struct DeleteResult: Identifiable {
        let id = UUID()
        let count: Int
        let bytes: Int64
    }

    private var totalBytes: Int64 { trashed.reduce(0) { $0 + $1.byteSize } }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            Button { dismiss() } label: {
                Image(systemName: "chevron.left")
                    .font(.system(size: 18, weight: .medium))
                    .foregroundStyle(Theme.ink)
                    .frame(width: 36, height: 36, alignment: .leading)
            }
            .accessibilityLabel("Zurück")

            if trashed.isEmpty {
                emptyState
            } else {
                content
            }
        }
        .padding(.horizontal, 20)
        .background(Theme.background.ignoresSafeArea())
        .toolbar(.hidden, for: .navigationBar)
        .onAppear(perform: reload)
        .onChange(of: trashed.count) { _, _ in reload() }
        .onChange(of: library.changeToken) { _, _ in reload() }
        .alert("Löschen hat nicht geklappt", isPresented: Binding(
            get: { errorMessage != nil },
            set: { if !$0 { errorMessage = nil } }
        )) {
            Button("Erneut versuchen") { deleteAll() }
            Button("Abbrechen", role: .cancel) {}
        } message: {
            Text(errorMessage ?? "")
        }
        .alert("Nicht alles ließ sich löschen", isPresented: Binding(
            get: { !undeletable.isEmpty },
            set: { if !$0 { undeletable = [] } }
        )) {
            Button("Aus dem Papierkorb nehmen") { keep(undeletable) }
            Button("Im Papierkorb lassen", role: .cancel) {}
        } message: {
            Text("iOS lässt \(Formatting.photos(undeletable.count)) nicht löschen, etwa weil sie aus einem geteilten Album stammen.")
        }
        .sheet(item: $result) { result in
            DeletedHintView(count: result.count, bytes: result.bytes)
                .presentationDetents([.large])
        }
    }

    private var content: some View {
        VStack(alignment: .leading, spacing: 0) {
            DisplayHeadline(lead: "Bereit zum\n", accent: "Loslassen", size: 42)
                .padding(.top, 6)
            Text("\(Formatting.photos(trashed.count)) · \(Formatting.bytes(totalBytes))")
                .font(.system(size: 14))
                .foregroundStyle(Theme.inkSecondary)
                .padding(.top, 8)

            ScrollView {
                LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 6), count: 4), spacing: 6) {
                    ForEach(items) { item in
                        Button { restore(item) } label: {
                            Color.clear
                                .aspectRatio(1, contentMode: .fit)
                                .overlay(AssetImageView(item: item, targetSize: CGSize(width: 90, height: 90)))
                                .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
                        }
                        .buttonStyle(PressScaleStyle())
                        .accessibilityLabel("Behalten")
                    }
                }
                .padding(.top, 16)
                Text("Tippe ein Foto an, um es doch zu behalten.")
                    .font(.system(size: 12))
                    .foregroundStyle(Theme.inkSecondary)
                    .frame(maxWidth: .infinity)
                    .padding(.top, 10)
            }

            NoteBox(title: "Danach wichtig:",
                    text: "In Fotos den Ordner „Zuletzt gelöscht“ leeren. Erst dann wird dein iCloud-Speicher frei. Yolk zeigt dir, wie.")
                .padding(.top, 12)

            Button(action: deleteAll) {
                HStack(spacing: 10) {
                    if isDeleting { ProgressView().tint(.white) }
                    Text(isDeleting ? "Wird gelöscht …" : "\(Formatting.photos(trashed.count)) löschen")
                }
            }
            .buttonStyle(PrimaryButtonStyle())
            .disabled(isDeleting)
            .padding(.top, 12)
            .padding(.bottom, 8)
        }
    }

    private var emptyState: some View {
        VStack(spacing: 14) {
            Spacer()
            DisplayHeadline(lead: "Der Papierkorb ist ", accent: "leer.", size: 38)
                .multilineTextAlignment(.center)
            Text("Alles, was du nach links wischst, landet erst einmal hier.")
                .font(.system(size: 15))
                .foregroundStyle(Theme.inkSecondary)
                .multilineTextAlignment(.center)
            Spacer()
        }
        .frame(maxWidth: .infinity)
    }

    // MARK: - Aktionen

    private func reload() {
        let ids = trashed.map(\.assetID)
        let found = library.items(withIDs: ids)
        let byID = Dictionary(found.map { ($0.id, $0) }, uniquingKeysWith: { first, _ in first })
        items = ids.compactMap { byID[$0] }
        // Bei eingeschränktem Zugriff fehlen auch Fotos außerhalb der Auswahl. Dann nichts entfernen.
        guard library.access == .authorized else { return }
        let gone = trashed.filter { byID[$0.assetID] == nil }
        guard !gone.isEmpty else { return }
        // Lief ein Löschauftrag in die Zeitgrenze und hat PhotoKit ihn doch noch erledigt, zählt er normal.
        let fromPending = gone.filter { pendingIDs.contains($0.assetID) }
        if !fromPending.isEmpty {
            credit(fromPending)
            pendingIDs = []
        }
        gone.forEach(context.delete)
        try? context.save()
    }

    private func restore(_ item: MediaItem) {
        guard let decision = trashed.first(where: { $0.assetID == item.id }) else { return }
        withAnimation(.easeOut(duration: 0.2)) {
            decision.kind = .keep
            decision.decidedAt = .now
            try? context.save()
        }
    }

    private func keep(_ batch: [MediaItem]) {
        let ids = Set(batch.map(\.id))
        for decision in trashed where ids.contains(decision.assetID) {
            decision.kind = .keep
            decision.decidedAt = .now
        }
        try? context.save()
    }

    /// Schreibt gelöschte Fotos dem Speicher-Zähler gut und zeigt den Hinweis zu „Zuletzt gelöscht“.
    private func credit(_ gone: [Decision]) {
        let bytes = gone.reduce(Int64(0)) { $0 + $1.byteSize }
        freedBytes += Int(bytes)
        result = DeleteResult(count: gone.count, bytes: bytes)
    }

    private func deleteAll() {
        guard !isDeleting, !items.isEmpty else { return }
        isDeleting = true
        let batch = items
        let ids = Set(batch.map(\.id))
        let skipped = batch.filter { !library.canDelete($0) }
        Task {
            defer { isDeleting = false }
            do {
                // Die Zeit läuft auch, während die iOS-Abfrage offen ist, daher großzügig.
                let confirmed = try await library.delete(batch, timeout: 120)
                guard confirmed else { return } // in der iOS-Abfrage abgebrochen
                let stillThere = library.existingIDs(Array(ids))
                let gone = trashed.filter { ids.contains($0.assetID) && !stillThere.contains($0.assetID) }
                if !gone.isEmpty { credit(gone) }
                gone.forEach(context.delete)
                try? context.save()
                undeletable = skipped.filter { stillThere.contains($0.id) }
            } catch PhotoLibrary.DeleteError.timedOut {
                pendingIDs = ids
                errorMessage = "Das Löschen hängt. Das ist ein bekannter iOS-Fehler. Schließe Yolk ganz und versuche es noch einmal."
            } catch {
                errorMessage = error.localizedDescription
            }
        }
    }
}
