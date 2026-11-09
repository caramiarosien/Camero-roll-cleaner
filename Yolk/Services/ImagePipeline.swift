import Photos
import UIKit

/// Gemeinsamer Bildlader für Karten, Raster und Vorladen: ein Cache, eine Optionen-Fabrik und eine Größenumrechnung.
/// Nur wenn Vorladen und Anzeigen dieselbe Pixelgröße, denselben Inhaltsmodus und dieselben Optionen nutzen,
/// kommt das Bild beim Anzeigen wirklich aus dem Cache.
enum ImagePipeline {
    struct Update {
        let image: UIImage
        /// `true` für die unscharfe Vorschau; die scharfe Fassung folgt.
        let isDegraded: Bool
    }

    static let manager: PHCachingImageManager = {
        let manager = PHCachingImageManager()
        // Nur schnelle Vorschauen vorhalten, die scharfe Fassung kommt beim Anzeigen (ab iOS 26 ohne Wirkung).
        manager.allowsCachingHighQualityImages = false
        return manager
    }()

    static let contentMode: PHImageContentMode = .aspectFill

    /// Pixel werden auf Vielfache davon aufgerundet, damit kleine Layout-Unterschiede den Cache nicht verfehlen.
    private static let pixelStep: CGFloat = 16
    private static let maxPixels: CGFloat = 8_192

    @MainActor private static var cachedScale: CGFloat?

    /// Bildschirmskalierung aus der aktiven Szene, einmal ermittelt und dann fest.
    @MainActor static var displayScale: CGFloat {
        if let cachedScale { return cachedScale }
        let scenes = UIApplication.shared.connectedScenes.compactMap { $0 as? UIWindowScene }
        let scene = scenes.first { $0.activationState == .foregroundActive } ?? scenes.first
        if let scale = scene?.traitCollection.displayScale, scale > 0 {
            cachedScale = scale
            return scale
        }
        let current = UITraitCollection.current.displayScale
        return current > 0 ? current : 3
    }

    /// Rechnet eine Größe in Punkten in die Pixelgröße um, mit der PhotoKit angefragt wird.
    /// Einzige Stelle dafür: Vorladen und `AssetImageView` nutzen beide diese Funktion.
    @MainActor static func pixelSize(for points: CGSize) -> CGSize {
        let scale = displayScale
        func pixels(_ value: CGFloat) -> CGFloat {
            guard value.isFinite, value > 0 else { return pixelStep }
            let raw = (value * scale / pixelStep).rounded(.up) * pixelStep
            return min(max(raw, pixelStep), maxPixels)
        }
        return CGSize(width: pixels(points.width), height: pixels(points.height))
    }

    static func requestOptions(allowNetwork: Bool) -> PHImageRequestOptions {
        let options = PHImageRequestOptions()
        options.deliveryMode = .opportunistic
        options.resizeMode = .fast
        options.version = .current
        options.isSynchronous = false
        options.isNetworkAccessAllowed = allowNetwork
        return options
    }

    /// Liefert erst die unscharfe, dann die scharfe Fassung und endet danach.
    /// Endet ohne Bild, wenn keins zu bekommen ist (fehlende Vorschau, iCloud-Fehler, kein Netz erlaubt).
    /// Bricht der Verbraucher ab (Task beendet), wird die PhotoKit-Anfrage abgebrochen.
    static func images(for asset: PHAsset, pixelSize: CGSize, allowNetwork: Bool) -> AsyncStream<Update> {
        AsyncStream(bufferingPolicy: .bufferingNewest(1)) { continuation in
            let requestID = manager.requestImage(
                for: asset,
                targetSize: pixelSize,
                contentMode: contentMode,
                options: requestOptions(allowNetwork: allowNetwork)
            ) { image, info in
                let isDegraded = (info?[PHImageResultIsDegradedKey] as? Bool) ?? false
                let isCancelled = (info?[PHImageCancelledKey] as? Bool) ?? false
                let failed = info?[PHImageErrorKey] != nil
                if let image {
                    continuation.yield(Update(image: image, isDegraded: isDegraded))
                }
                if !isDegraded || isCancelled || failed {
                    continuation.finish()
                }
            }
            continuation.onTermination = { _ in
                manager.cancelImageRequest(requestID)
            }
        }
    }

    static func startCaching(_ assets: [PHAsset], pixelSize: CGSize, allowNetwork: Bool) {
        guard !assets.isEmpty else { return }
        manager.startCachingImages(
            for: assets,
            targetSize: pixelSize,
            contentMode: contentMode,
            options: requestOptions(allowNetwork: allowNetwork)
        )
    }

    static func stopCaching(_ assets: [PHAsset], pixelSize: CGSize, allowNetwork: Bool) {
        guard !assets.isEmpty else { return }
        manager.stopCachingImages(
            for: assets,
            targetSize: pixelSize,
            contentMode: contentMode,
            options: requestOptions(allowNetwork: allowNetwork)
        )
    }

    static func resetCaching() {
        manager.stopCachingImagesForAllAssets()
    }
}
