import Photos
import PhotosUI
import SwiftUI
import Synchronization
import UIKit

/// Zugang zur Mediathek über PhotoKit. Alles läuft auf dem Gerät.
///
/// SCHNITTSTELLE (von der Oberfläche benutzt, Signaturen nicht ändern):
///   access, changeToken, refreshAccess(), requestAccess(), fetchAll(), items(withIDs:),
///   byteSize(of:), canDelete(_:), delete(_:timeout:), setFavorite(_:_:), openPhotosApp(),
///   openSettings(), presentLimitedLibraryPicker()
///   sowie die View `AssetImageView` in Services/AssetImageView.swift.
/// ZUSÄTZLICH: byteSizes(of:) (viele Größen ohne Hauptthread-Last),
///   startCaching(_:targetSize:allowNetwork:), stopCaching(_:targetSize:allowNetwork:), resetCaching()
///   zum Vorladen der nächsten Karten.
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
    /// Schnell aufeinander folgende Änderungen (etwa beim iCloud-Abgleich) werden zusammengefasst.
    @Published private(set) var changeToken: Int = 0

    private var isObservingLibrary = false
    private var pendingChangeBump: Task<Void, Never>?
    private var sizeCache: [String: SizeEntry] = [:]

    private struct SizeEntry {
        /// Änderungsdatum des Assets bei der Messung. Ändert es sich (Bearbeitung), wird neu gemessen.
        let modified: Date?
        let bytes: Int64
        let isExact: Bool

        init(modified: Date?, size: AssetByteSize.Size) {
            self.modified = modified
            self.bytes = size.bytes
            self.isExact = size.isExact
        }
    }

    override init() {
        super.init()
        refreshAccess()
    }

    deinit {
        if isObservingLibrary {
            PHPhotoLibrary.shared().unregisterChangeObserver(self)
        }
    }

    // MARK: - Zugriff

    func refreshAccess() {
        apply(PHPhotoLibrary.authorizationStatus(for: .readWrite))
    }

    func requestAccess() async -> Access {
        let status = await PHPhotoLibrary.requestAuthorization(for: .readWrite)
        apply(status)
        return access
    }

    private func apply(_ status: PHAuthorizationStatus) {
        let newAccess = Self.map(status)
        if access != newAccess { access = newAccess }
        observeLibraryIfAllowed()
    }

    /// Erst nach erteiltem Zugriff anmelden; vorher würde die Anmeldung selbst die iOS-Abfrage auslösen.
    private func observeLibraryIfAllowed() {
        guard !isObservingLibrary, access == .authorized || access == .limited else { return }
        PHPhotoLibrary.shared().register(self)
        isObservingLibrary = true
    }

    // MARK: - Abfragen

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

    // MARK: - Größe

    /// Größe aller Dateien eines Eintrags in Bytes (Live Photo, RAW+JPEG, Bearbeitungen zusammen).
    /// Exakt, wenn iOS die Größe meldet, sonst geschätzt; 0 nur, wenn auch keine Schätzung möglich ist.
    /// Das Ergebnis wird je Asset gemerkt, wiederholte Aufrufe kosten fast nichts.
    func byteSize(of item: MediaItem) -> Int64 {
        let modified = item.asset.modificationDate
        if let entry = sizeCache[item.id], entry.modified == modified {
            return entry.bytes
        }
        let size = AssetByteSize.measure(item.asset)
        sizeCache[item.id] = SizeEntry(modified: modified, size: size)
        return size.bytes
    }

    /// Größen vieler Einträge (etwa um Videos nach Größe zu sortieren). Gemessen wird abseits des Hauptthreads,
    /// die Ergebnisse landen im selben Cache wie bei `byteSize(of:)`. Schlüssel ist `MediaItem.id`.
    /// Wird die aufrufende Task abgebrochen, fehlen die noch nicht gemessenen Einträge im Ergebnis.
    func byteSizes(of items: [MediaItem]) async -> [String: Int64] {
        var sizes: [String: Int64] = [:]
        sizes.reserveCapacity(items.count)
        var missing: [PHAsset] = []
        var seen = Set<String>()
        for item in items where seen.insert(item.id).inserted {
            if let entry = sizeCache[item.id], entry.modified == item.asset.modificationDate {
                sizes[item.id] = entry.bytes
            } else {
                missing.append(item.asset)
            }
        }
        guard !missing.isEmpty else { return sizes }
        let measured = await AssetByteSize.measureInBackground(missing)
        for entry in measured {
            sizeCache[entry.id] = SizeEntry(modified: entry.modified, size: entry.size)
            sizes[entry.id] = entry.size.bytes
        }
        return sizes
    }

    // MARK: - Ändern

    func canDelete(_ item: MediaItem) -> Bool {
        item.asset.canPerform(.delete)
    }

    /// Verschiebt alle Einträge in einem Schritt nach „Zuletzt gelöscht“ (eine iOS-Abfrage).
    /// Einträge, die iOS nicht löschen darf, werden übersprungen.
    /// - Returns: `true`, wenn gelöscht wurde, `false`, wenn der Nutzer in der iOS-Abfrage abgebrochen hat.
    /// - Throws: `DeleteError.timedOut`, wenn PhotoKit nach `timeout` Sekunden nicht geantwortet hat (bekannter
    ///   Apple-Fehler; die Zeit läuft ab dem Aufruf, also inklusive der iOS-Abfrage). PhotoKit kann danach trotzdem
    ///   noch löschen, `changeToken` meldet das dann. `DeleteError.failed` bei anderen Fehlern.
    func delete(_ items: [MediaItem], timeout: TimeInterval = 60) async throws -> Bool {
        let assets = Self.unique(items.map(\.asset)).filter { $0.canPerform(.delete) }
        guard !assets.isEmpty else { return true }
        do {
            try await Self.performChanges(Self.deleteChange(for: assets), timeout: timeout)
        } catch let error as DeleteError {
            throw error
        } catch {
            if Self.isUserCancellation(error) { return false }
            throw DeleteError.failed(error.localizedDescription)
        }
        for asset in assets {
            sizeCache[asset.localIdentifier] = nil
        }
        return true
    }

    /// Setzt oder entfernt die Favoriten-Markierung für alle Einträge in einem Schritt.
    /// Einträge, deren Eigenschaften iOS nicht ändern darf, werden übersprungen.
    func setFavorite(_ items: [MediaItem], _ isFavorite: Bool) async throws {
        let assets = Self.unique(items.map(\.asset)).filter { $0.canPerform(.properties) }
        guard !assets.isEmpty else { return }
        try await PHPhotoLibrary.shared().performChanges(Self.favoriteChange(for: assets, isFavorite: isFavorite))
    }

    // MARK: - Vorladen

    /// Lädt Vorschauen für die nächsten Karten vor. `targetSize` in Punkten, genau wie bei `AssetImageView`.
    func startCaching(_ items: [MediaItem], targetSize: CGSize, allowNetwork: Bool = true) {
        ImagePipeline.startCaching(items.map(\.asset), pixelSize: ImagePipeline.pixelSize(for: targetSize), allowNetwork: allowNetwork)
    }

    /// Gibt vorgeladene Vorschauen frei (etwa für weggewischte Karten). Gleiche Größe wie bei `startCaching`.
    func stopCaching(_ items: [MediaItem], targetSize: CGSize, allowNetwork: Bool = true) {
        ImagePipeline.stopCaching(items.map(\.asset), pixelSize: ImagePipeline.pixelSize(for: targetSize), allowNetwork: allowNetwork)
    }

    func resetCaching() {
        ImagePipeline.resetCaching()
    }

    // MARK: - Andere Apps und Systemdialoge

    func openPhotosApp() {
        if let url = URL(string: "photos-redirect://") { UIApplication.shared.open(url) }
    }

    func openSettings() {
        if let url = URL(string: UIApplication.openSettingsURLString) { UIApplication.shared.open(url) }
    }

    /// Zeigt die iOS-Auswahl für „Ausgewählte Fotos“. Nur bei eingeschränktem Zugriff.
    func presentLimitedLibraryPicker() {
        refreshAccess()
        guard access == .limited, let presenter = Self.topViewController() else { return }
        PHPhotoLibrary.shared().presentLimitedLibraryPicker(from: presenter, completionHandler: Self.pickerCompletion(for: self))
    }

    private func limitedPickerDidFinish() {
        refreshAccess()
        scheduleChangeBump()
    }

    // MARK: - Änderungen der Mediathek

    private func libraryDidChange() {
        scheduleChangeBump()
    }

    /// Fasst Änderungen innerhalb kurzer Zeit zu einem Hochzählen zusammen.
    private func scheduleChangeBump() {
        guard pendingChangeBump == nil else { return }
        pendingChangeBump = Task { [weak self] in
            try? await Task.sleep(for: .milliseconds(250))
            self?.finishChangeBump()
        }
    }

    private func finishChangeBump() {
        pendingChangeBump = nil
        // Geschätzte Größen neu versuchen: iOS kennt sie oft erst, wenn eine Datei fertig verarbeitet ist.
        sizeCache = sizeCache.filter { $0.value.isExact }
        changeToken &+= 1
    }

    // MARK: - Hilfen

    private static func map(_ status: PHAuthorizationStatus) -> Access {
        switch status {
        case .authorized: return .authorized
        case .limited: return .limited
        case .denied, .restricted: return .denied
        case .notDetermined: return .notDetermined
        @unknown default: return .denied
        }
    }

    private static func unique(_ assets: [PHAsset]) -> [PHAsset] {
        var seen = Set<String>()
        return assets.filter { seen.insert($0.localIdentifier).inserted }
    }

    private static func topViewController() -> UIViewController? {
        let scenes = UIApplication.shared.connectedScenes.compactMap { $0 as? UIWindowScene }
        let scene = scenes.first { $0.activationState == .foregroundActive } ?? scenes.first
        let window = scene?.keyWindow ?? scene?.windows.first
        var top = window?.rootViewController
        while let presented = top?.presentedViewController, !presented.isBeingDismissed {
            top = presented
        }
        return top
    }

    /// Fehler 3072 (`PHPhotosError.userCancelled`, gleicher Code wie `NSUserCancelledError`): Abbruch in der iOS-Abfrage.
    nonisolated private static func isUserCancellation(_ error: any Error) -> Bool {
        if let photosError = error as? PHPhotosError, photosError.code == .userCancelled {
            return true
        }
        let nsError = error as NSError
        let cancelCode = PHPhotosError.Code.userCancelled.rawValue
        return nsError.code == cancelCode
            && (nsError.domain == PHPhotosError.errorDomain || nsError.domain == NSCocoaErrorDomain)
    }

    // Die folgenden Closures entstehen bewusst außerhalb des Main Actors: PhotoKit ruft sie auf eigenen Queues auf.

    nonisolated private static func deleteChange(for assets: [PHAsset]) -> @Sendable () -> Void {
        { PHAssetChangeRequest.deleteAssets(assets as NSArray) }
    }

    nonisolated private static func favoriteChange(for assets: [PHAsset], isFavorite: Bool) -> @Sendable () -> Void {
        {
            for asset in assets {
                PHAssetChangeRequest(for: asset).isFavorite = isFavorite
            }
        }
    }

    nonisolated private static func pickerCompletion(for library: PhotoLibrary) -> @Sendable ([String]) -> Void {
        { _ in
            Task { @MainActor in library.limitedPickerDidFinish() }
        }
    }

    /// `performChanges` mit Zeitgrenze. Bewusst ohne Task-Gruppe: Eine Gruppe wartet auf alle Kinder,
    /// und ein hängendes `performChanges` endet nie. Wer zuerst fertig ist (PhotoKit oder Uhr), setzt fort.
    nonisolated private static func performChanges(_ changes: @escaping @Sendable () -> Void, timeout: TimeInterval) async throws {
        try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Void, any Error>) in
            let once = ResumeOnce(continuation)
            PHPhotoLibrary.shared().performChanges(changes) { success, error in
                if success {
                    once.resume(with: .success(()))
                } else {
                    once.resume(with: .failure(error ?? DeleteError.failed("Das Löschen ist fehlgeschlagen.")))
                }
            }
            if timeout.isFinite {
                DispatchQueue.global(qos: .userInitiated).asyncAfter(deadline: .now() + max(timeout, 1)) {
                    once.resume(with: .failure(DeleteError.timedOut))
                }
            }
        }
    }
}

extension PhotoLibrary: PHPhotoLibraryChangeObserver {
    /// Kommt auf einer Hintergrund-Queue an; der Zustand wird auf dem Main Actor geändert.
    nonisolated func photoLibraryDidChange(_ changeInstance: PHChange) {
        Task { @MainActor [weak self] in
            self?.libraryDidChange()
        }
    }
}

/// Setzt eine Continuation genau einmal fort, egal wer zuerst kommt.
private final class ResumeOnce: Sendable {
    private let continuation: Mutex<CheckedContinuation<Void, any Error>?>

    init(_ continuation: CheckedContinuation<Void, any Error>) {
        self.continuation = Mutex(continuation)
    }

    func resume(with result: Result<Void, any Error>) {
        let pending = continuation.withLock { stored -> CheckedContinuation<Void, any Error>? in
            let current = stored
            stored = nil
            return current
        }
        pending?.resume(with: result)
    }
}
