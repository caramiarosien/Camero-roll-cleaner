import Photos

/// Ein Foto oder Video aus der Mediathek. Die Identität ist der `localIdentifier` des PHAsset.
struct MediaItem: Identifiable, Hashable {
    let asset: PHAsset

    var id: String { asset.localIdentifier }
    var creationDate: Date? { asset.creationDate }
    var isVideo: Bool { asset.mediaType == .video }
    var duration: TimeInterval { asset.duration }
    var pixelSize: CGSize { CGSize(width: asset.pixelWidth, height: asset.pixelHeight) }

    static func == (lhs: MediaItem, rhs: MediaItem) -> Bool { lhs.id == rhs.id }
    func hash(into hasher: inout Hasher) { hasher.combine(id) }
}
