import Photos

/// Leichte Abfragen für den Startbildschirm, ohne die ganze Mediathek in ein Array zu laden.
extension PhotoLibrary {
    /// Anzahl aller Fotos und Videos.
    func totalCount() -> Int {
        PHAsset.fetchAssets(with: nil).count
    }

    /// Die neuesten Einträge, über die noch nicht entschieden wurde. Bricht ab, sobald `limit` erreicht ist.
    func newestItems(excluding decided: Set<String>, limit: Int) -> [MediaItem] {
        guard limit > 0 else { return [] }
        let options = PHFetchOptions()
        options.sortDescriptors = [NSSortDescriptor(key: "creationDate", ascending: false)]
        let result = PHAsset.fetchAssets(with: options)
        var items: [MediaItem] = []
        result.enumerateObjects { asset, _, stop in
            if !decided.contains(asset.localIdentifier) {
                items.append(MediaItem(asset: asset))
                if items.count >= limit { stop.pointee = true }
            }
        }
        return items
    }

    /// IDs aus `ids`, die es in der Mediathek noch gibt.
    func existingIDs(_ ids: [String]) -> Set<String> {
        guard !ids.isEmpty else { return [] }
        let result = PHAsset.fetchAssets(withLocalIdentifiers: ids, options: nil)
        var found = Set<String>()
        result.enumerateObjects { asset, _, _ in found.insert(asset.localIdentifier) }
        return found
    }
}
