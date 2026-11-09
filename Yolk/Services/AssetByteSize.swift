import Photos
import UniformTypeIdentifiers

/// Ermittelt, wie viele Bytes ein Eintrag belegt. Ohne Zustand und von jedem Thread aus nutzbar;
/// den Cache hält `PhotoLibrary`.
///
/// Reihenfolge je Datei (`PHAssetResource`):
/// 1. ab iOS 27 das offizielle Feld `dataSize`,
/// 2. das nicht dokumentierte Feld `fileSize` (iOS 18–26, abgesichert, stürzt nie ab),
/// 3. eine Schätzung aus Auflösung, Dateityp und Länge.
enum AssetByteSize {
    struct Size {
        let bytes: Int64
        /// `true`, wenn iOS für jede Datei eine Größe gemeldet hat.
        let isExact: Bool
    }

    struct Measured {
        let id: String
        let modified: Date?
        let size: Size
    }

    /// Summe aller Dateien eines Eintrags (Live Photo, RAW+JPEG und bearbeitete Fotos haben mehrere).
    static func measure(_ asset: PHAsset) -> Size {
        let resources = PHAssetResource.assetResources(for: asset)
        guard !resources.isEmpty else {
            return Size(bytes: estimate(asset), isExact: false)
        }
        var total: Int64 = 0
        var isExact = true
        for resource in resources {
            if let reported = reportedSize(of: resource) {
                total = saturatingAdd(total, reported)
            } else {
                isExact = false
                total = saturatingAdd(total, estimate(resource, of: asset))
            }
        }
        return Size(bytes: total, isExact: isExact)
    }

    /// Misst viele Einträge abseits des Hauptthreads. Bricht bei Task-Abbruch ab und liefert, was bis dahin fertig ist.
    @concurrent
    static func measureInBackground(_ assets: [PHAsset]) async -> [Measured] {
        var results: [Measured] = []
        results.reserveCapacity(assets.count)
        for asset in assets {
            if Task.isCancelled { break }
            results.append(Measured(id: asset.localIdentifier, modified: asset.modificationDate, size: measure(asset)))
        }
        return results
    }

    // MARK: - Gemeldete Größe

    private static func reportedSize(of resource: PHAssetResource) -> Int64? {
        if #available(iOS 27, *) {
            // `nil` heißt hier „unbekannt“, nicht 0.
            if let size = resource.dataSize, size >= 0 {
                return Int64(size)
            }
        }
        return legacyFileSize(of: resource)
    }

    private static let fileSizeKey = "fileSize"
    private static let fileSizeSelector = NSSelectorFromString("fileSize")

    /// Nicht dokumentiertes Feld. Nur lesen, wenn es den Getter gibt: KVC auf einen fehlenden Schlüssel
    /// wirft eine Objective-C-Ausnahme, die Swift nicht fangen kann.
    private static func legacyFileSize(of resource: PHAssetResource) -> Int64? {
        guard resource.responds(to: fileSizeSelector) else { return nil }
        let value: Int64?
        switch resource.value(forKey: fileSizeKey) {
        case let number as NSNumber: value = number.int64Value
        case let int64 as Int64: value = int64
        case let int as Int: value = Int64(int)
        default: value = nil
        }
        guard let value, value > 0 else { return nil }
        return value
    }

    // MARK: - Schätzung

    /// Typische Live-Photo-Videoauflösung, falls iOS keine nennt.
    private static let pairedVideoPixels: Double = 1920 * 1440
    private static let pairedVideoSeconds: TimeInterval = 3

    private static func estimate(_ resource: PHAssetResource, of asset: PHAsset) -> Int64 {
        let resourcePixels = pixels(resource.pixelWidth, resource.pixelHeight)
        let assetPixels = pixels(asset.pixelWidth, asset.pixelHeight)
        let pixelCount = resourcePixels > 0 ? resourcePixels : assetPixels

        switch resource.type {
        case .photo, .fullSizePhoto, .alternatePhoto, .adjustmentBasePhoto, .photoProxy:
            return clamp(pixelCount * bytesPerPixel(contentType(of: resource)))
        case .video, .fullSizeVideo, .adjustmentBaseVideo:
            return videoBytes(pixels: pixelCount, duration: asset.duration)
        case .pairedVideo, .fullSizePairedVideo, .adjustmentBasePairedVideo:
            let paired = resourcePixels > 0 ? resourcePixels : min(assetPixels, pairedVideoPixels)
            return videoBytes(pixels: paired, duration: pairedVideoSeconds)
        case .audio:
            return clamp(validDuration(asset.duration) * 256_000 / 8)
        case .adjustmentData:
            return 4_096
        default:
            return 0
        }
    }

    /// Schätzung für Einträge, zu denen iOS (noch) keine Dateien nennt.
    private static func estimate(_ asset: PHAsset) -> Int64 {
        let pixelCount = pixels(asset.pixelWidth, asset.pixelHeight)
        switch asset.mediaType {
        case .video:
            return videoBytes(pixels: pixelCount, duration: asset.duration)
        case .image:
            var bytes = clamp(pixelCount * bytesPerPixel(nil))
            if asset.mediaSubtypes.contains(.photoLive) {
                bytes = saturatingAdd(bytes, videoBytes(pixels: min(pixelCount, pairedVideoPixels), duration: pairedVideoSeconds))
            }
            return bytes
        case .audio:
            return clamp(validDuration(asset.duration) * 256_000 / 8)
        default:
            return 0
        }
    }

    /// Länge × auflösungsabhängige Bitrate. Etwa 0,1 Bit pro Pixel und Bild bei 30 Bildern/s
    /// (1080p ≈ 6 Mbit/s, 4K ≈ 25 Mbit/s, wie HEVC auf dem iPhone), plus Ton.
    private static func videoBytes(pixels: Double, duration: TimeInterval) -> Int64 {
        let seconds = validDuration(duration)
        guard seconds > 0, pixels > 0 else { return 0 }
        let videoBitsPerSecond = max(pixels * 3.0, 1_000_000)
        let audioBitsPerSecond = 128_000.0
        return clamp((videoBitsPerSecond + audioBitsPerSecond) * seconds / 8)
    }

    private static func contentType(of resource: PHAssetResource) -> UTType? {
        if #available(iOS 26, *) {
            return resource.contentType
        }
        return UTType(resource.uniformTypeIdentifier)
    }

    private static func bytesPerPixel(_ type: UTType?) -> Double {
        guard let type else { return 0.3 }
        if type.conforms(to: .rawImage) { return 1.6 }
        if type.conforms(to: .heic) || type.conforms(to: .heif) { return 0.25 }
        if type.conforms(to: .jpeg) { return 0.45 }
        if type.conforms(to: .png) { return 0.6 }
        return 0.35
    }

    // MARK: - Rechenhilfen, die nie abstürzen

    private static func pixels(_ width: Int, _ height: Int) -> Double {
        guard width > 0, height > 0 else { return 0 }
        return Double(width) * Double(height)
    }

    private static func validDuration(_ duration: TimeInterval) -> TimeInterval {
        duration.isFinite && duration > 0 ? duration : 0
    }

    private static func clamp(_ value: Double) -> Int64 {
        guard value.isFinite, value > 0 else { return 0 }
        guard value < 9.0e18 else { return Int64.max }
        return Int64(value)
    }

    private static func saturatingAdd(_ lhs: Int64, _ rhs: Int64) -> Int64 {
        let (sum, overflow) = lhs.addingReportingOverflow(max(rhs, 0))
        return overflow ? Int64.max : sum
    }
}
