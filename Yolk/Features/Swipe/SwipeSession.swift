import SwiftData
import SwiftUI

/// Stapel zum Durchwischen: alle Fotos, über die noch nicht entschieden wurde, neueste zuerst.
@MainActor
final class SwipeSession: ObservableObject {
    @Published private(set) var queue: [MediaItem] = []
    @Published private(set) var position = 0
    @Published private(set) var isLoaded = false

    private var history: [MediaItem] = []
    private let library: PhotoLibrary
    private var context: ModelContext?

    init(library: PhotoLibrary) {
        self.library = library
    }

    func attach(_ context: ModelContext) {
        self.context = context
    }

    func load() {
        guard let context else { return }
        let decided = Set(((try? context.fetch(FetchDescriptor<Decision>())) ?? []).map(\.assetID))
        queue = library.fetchAll().filter { !decided.contains($0.id) }
        position = 0
        history = []
        isLoaded = true
    }

    var current: MediaItem? { position < queue.count ? queue[position] : nil }
    var remaining: Int { max(0, queue.count - position) }
    var total: Int { queue.count }
    var canUndo: Bool { !history.isEmpty }

    func upcoming(_ count: Int) -> [MediaItem] {
        Array(queue.dropFirst(position).prefix(count))
    }

    func decide(_ kind: DecisionKind) {
        guard let item = current, let context else { return }
        let size = library.byteSize(of: item)
        if let existing = decision(for: item.id) {
            existing.kind = kind
            existing.byteSize = size
            existing.decidedAt = .now
        } else {
            context.insert(Decision(assetID: item.id, kind: kind, byteSize: size))
        }
        try? context.save()
        history.append(item)
        position += 1
    }

    /// Der zuletzt entschiedene Eintrag, etwa um seinen Bild-Cache freizugeben.
    var lastDecided: MediaItem? { history.last }

    /// Nimmt den letzten Wisch zurück. Geht auch mehrfach hintereinander.
    func undo() {
        pruneMissing()
        guard let item = history.popLast(), let context else { return }
        if let existing = decision(for: item.id) {
            context.delete(existing)
            try? context.save()
        }
        position = max(0, position - 1)
    }

    /// Entfernt Fotos, die inzwischen gelöscht wurden (im Papierkorb oder in der Fotos-App),
    /// aus Verlauf und den nächsten Karten. Sonst brächte Rückgängig leere Karten zurück.
    func pruneMissing(lookahead: Int = 30) {
        let window = history.map(\.id) + upcoming(lookahead).map(\.id)
        guard !window.isEmpty else { return }
        let missing = Set(window).subtracting(library.existingIDs(window))
        guard !missing.isEmpty else { return }
        var kept: [MediaItem] = []
        kept.reserveCapacity(queue.count)
        var newPosition = position
        for (index, item) in queue.enumerated() {
            if missing.contains(item.id) {
                if index < position { newPosition -= 1 }
            } else {
                kept.append(item)
            }
        }
        queue = kept
        position = max(0, newPosition)
        history.removeAll { missing.contains($0.id) }
    }

    private func decision(for assetID: String) -> Decision? {
        let id = assetID
        var descriptor = FetchDescriptor<Decision>(predicate: #Predicate { $0.assetID == id })
        descriptor.fetchLimit = 1
        return try? context?.fetch(descriptor).first
    }
}
