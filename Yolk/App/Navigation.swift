import SwiftData
import SwiftUI

/// Ziele im Navigationsstapel des Startbildschirms.
enum Route: Hashable {
    case swipe
    case trash
}

/// Ein einziger, wertbasierter Stapel für die ganze App. Früher öffneten Start und Wischen den Papierkorb je über ein
/// eigenes `navigationDestination(isPresented:)`; SwiftUI geriet dabei in eine endlose Neuberechnung und fror ein.
@MainActor
final class Navigator: ObservableObject {
    @Published var path: [Route] = []

    func open(_ route: Route) {
        path.append(route)
    }
}

#if DEBUG
/// Nur für Tests im Simulator, wo niemand tippen kann. Beispiel:
/// `SIMCTL_CHILD_YOLK_SEED_TRASH=3 SIMCTL_CHILD_YOLK_PATH=swipe,trash xcrun simctl launch booted <Bundle-ID>`
enum DebugLaunch {
    @MainActor
    static func apply(context: ModelContext, library: PhotoLibrary, navigator: Navigator) {
        let env = ProcessInfo.processInfo.environment
        if let count = Int(env["YOLK_SEED_TRASH"] ?? ""), count > 0 {
            let decided = Set(((try? context.fetch(FetchDescriptor<Decision>())) ?? []).map(\.assetID))
            for item in library.fetchAll().filter({ !decided.contains($0.id) }).prefix(count) {
                context.insert(Decision(assetID: item.id, kind: .trash, byteSize: library.byteSize(of: item)))
            }
            try? context.save()
        }
        if let raw = env["YOLK_PATH"] {
            navigator.path = raw.split(separator: ",").compactMap { part in
                switch part {
                case "swipe": return .swipe
                case "trash": return .trash
                default: return nil
                }
            }
        }
    }
}
#endif
