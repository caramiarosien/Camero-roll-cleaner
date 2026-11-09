import Photos
import SwiftUI
import UIKit

/// Zugang zur Mediathek über PhotoKit. Alles läuft auf dem Gerät.
///
/// SCHNITTSTELLE (von der Oberfläche benutzt, Signaturen nicht ändern):
///   access, changeToken, refreshAccess(), requestAccess(), fetchAll(), items(withIDs:),
///   byteSize(of:), canDelete(_:), delete(_:timeout:), setFavorite(_:_:), openPhotosApp(),
///   openSettings(), presentLimitedLibraryPicker()
///   sowie die View `AssetImageView` in Services/AssetImageView.swift.
@MainActor
final class PhotoLibrary: NSObject, ObservableObject {
    enum Access: Equatable {
        case notDetermined
        case authorized
        case limited
        case denied
    }

    enum DeleteError: LocalizedError {
        case timedOut
        case failed(String)

        var errorDescription: String? {
            switch self {
            case .timedOut: return "Das Löschen hat zu lange gedauert."
            case .failed(let message): return message
            }
        }
    }

    static let shared = PhotoLibrary()

    @Published private(set) var access: Access = .notDetermined
    /// Zählt bei jeder Änderung der Mediathek hoch, damit Ansichten neu laden können.
    @Published private(set) var changeToken: Int = 0

    override init() {
        super.init()
        refreshAccess()
    }

    func refreshAccess() {
        access = Self.map(PHPhotoLibrary.authorizationStatus(for: .readWrite))
    }

    func requestAccess() async -> Access {
        let status = await PHPhotoLibrary.requestAuthorization(for: .readWrite)
        access = Self.map(status)
        return access
    }

    /// Alle Fotos und Videos, neueste zuerst.
    func fetchAll() -> [MediaItem] {
        let options = PHFetchOptions()
        options.sortDescriptors = [NSSortDescriptor(key: "creationDate", ascending: false)]
        let result = PHAsset.fetchAssets(with: options)
        var items: [MediaItem] = []
        items.reserveCapacity(result.count)
        result.enumerateObjects { asset, _, _ in items.append(MediaItem(asset: asset)) }
        return items
    }

    func items(withIDs ids: [String]) -> [MediaItem] {
        guard !ids.isEmpty else { return [] }
        let result = PHAsset.fetchAssets(withLocalIdentifiers: ids, options: nil)
        var items: [MediaItem] = []
        result.enumerateObjects { asset, _, _ in items.append(MediaItem(asset: asset)) }
        return items
    }

    /// Geschätzte Größe aller Dateien eines Eintrags in Bytes. 0, wenn unbekannt.
    func byteSize(of item: MediaItem) -> Int64 {
        0 // Platzhalter, wird vom Subagenten ersetzt
    }

    func canDelete(_ item: MediaItem) -> Bool {
        item.asset.canPerform(.delete)
    }

    /// Verschiebt alle Einträge in einem Schritt nach „Zuletzt gelöscht“ (eine iOS-Abfrage).
    /// - Returns: `true`, wenn gelöscht wurde, `false`, wenn der Nutzer in der iOS-Abfrage abgebrochen hat.
    func delete(_ items: [MediaItem], timeout: TimeInterval = 60) async throws -> Bool {
        let assets = items.map(\.asset) as NSArray
        try await PHPhotoLibrary.shared().performChanges {
            PHAssetChangeRequest.deleteAssets(assets)
        }
        return true
    }

    func setFavorite(_ items: [MediaItem], _ isFavorite: Bool) async throws {
        try await PHPhotoLibrary.shared().performChanges {
            for item in items {
                PHAssetChangeRequest(for: item.asset).isFavorite = isFavorite
            }
        }
    }

    func openPhotosApp() {
        if let url = URL(string: "photos-redirect://") { UIApplication.shared.open(url) }
    }

    func openSettings() {
        if let url = URL(string: UIApplication.openSettingsURLString) { UIApplication.shared.open(url) }
    }

    func presentLimitedLibraryPicker() {}

    private static func map(_ status: PHAuthorizationStatus) -> Access {
        switch status {
        case .authorized: return .authorized
        case .limited: return .limited
        case .denied, .restricted: return .denied
        case .notDetermined: return .notDetermined
        @unknown default: return .denied
        }
    }
}
