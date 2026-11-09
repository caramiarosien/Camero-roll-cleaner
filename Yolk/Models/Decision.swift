import Foundation
import SwiftData

enum DecisionKind: String, Codable, CaseIterable {
    case keep
    case trash
    case favorite
    case later
}

/// Eine gemerkte Entscheidung zu einem Foto. Bleibt über App-Neustarts und die 7-Tage-Erneuerung erhalten.
@Model
final class Decision {
    @Attribute(.unique) var assetID: String
    var kindRaw: String
    var decidedAt: Date
    /// Geschätzte Größe in Bytes zum Zeitpunkt der Entscheidung (für Papierkorb-Summe und Speicher-Zähler).
    var byteSize: Int64

    init(assetID: String, kind: DecisionKind, byteSize: Int64, decidedAt: Date = .now) {
        self.assetID = assetID
        self.kindRaw = kind.rawValue
        self.byteSize = byteSize
        self.decidedAt = decidedAt
    }

    var kind: DecisionKind {
        get { DecisionKind(rawValue: kindRaw) ?? .keep }
        set { kindRaw = newValue.rawValue }
    }
}

/// Schlüssel für einfache Zähler in UserDefaults.
enum StatsKey {
    /// Summe der Bytes, die Yolk nach „Zuletzt gelöscht“ verschoben hat.
    static let freedBytes = "freedBytes"
}
