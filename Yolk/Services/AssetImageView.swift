import Photos
import SwiftUI

/// Zeigt das Bild eines Eintrags: erst unscharf, dann scharf.
/// Füllt den angebotenen Platz (Hintergrund `Theme.placeholder`) und schneidet bei `.fill` auf diesen Rahmen zu.
/// Nutzt denselben Cache wie `PhotoLibrary.startCaching`, vorgeladene Bilder erscheinen deshalb sofort.
/// Kommt kein Bild (fehlende Vorschau, iCloud-Fehler), erscheint ein dezentes Symbol statt endlosen Wartens.
///
/// SCHNITTSTELLE: `AssetImageView(item:targetSize:contentMode:)`, optional zusätzlich `allowNetwork:`.
struct AssetImageView: View {
    let item: MediaItem
    /// Gewünschte Bildgröße in Punkten, meist die Anzeigegröße. Für Cache-Treffer dieselbe Größe wie beim Vorladen.
    var targetSize: CGSize
    var contentMode: ContentMode = .fill
    /// Darf iOS Originale aus iCloud nachladen? Ohne Netz bleibt es bei der lokalen Vorschau.
    var allowNetwork: Bool = true

    @State private var image: UIImage?
    @State private var imageItemID: String?
    @State private var sharpKey: RequestKey?
    @State private var showsFallback = false

    /// Ab dann gilt ein Bild als ausgeblieben; die Anfrage läuft trotzdem weiter.
    private static let fallbackDelay: Duration = .seconds(8)

    init(item: MediaItem, targetSize: CGSize, contentMode: ContentMode = .fill, allowNetwork: Bool = true) {
        self.item = item
        self.targetSize = targetSize
        self.contentMode = contentMode
        self.allowNetwork = allowNetwork
    }

    var body: some View {
        let key = requestKey
        Theme.placeholder
            .overlay {
                if let image {
                    Image(uiImage: image)
                        .resizable()
                        .aspectRatio(contentMode: contentMode)
                } else if showsFallback {
                    Image(systemName: item.isVideo ? "video" : "photo")
                        .font(.system(size: 22, weight: .light))
                        .foregroundStyle(Theme.inkSecondary)
                        .accessibilityHidden(true)
                }
            }
            .clipped()
            .contentShape(Rectangle())
            .task(id: key) { await load(key) }
    }

    private var requestKey: RequestKey {
        let size = ImagePipeline.pixelSize(for: targetSize)
        return RequestKey(itemID: item.id, width: Int(size.width), height: Int(size.height), allowNetwork: allowNetwork)
    }

    /// Läuft, solange die Ansicht sichtbar ist. Verschwindet sie oder wechselt der Eintrag, bricht SwiftUI die Task ab;
    /// damit endet der Bildstrom und die PhotoKit-Anfrage wird abgebrochen.
    private func load(_ key: RequestKey) async {
        if imageItemID != key.itemID {
            image = nil
            sharpKey = nil
            showsFallback = false
            imageItemID = key.itemID
        } else if sharpKey == key {
            return
        }

        let fallback = Task {
            try? await Task.sleep(for: Self.fallbackDelay)
            if !Task.isCancelled, image == nil { showsFallback = true }
        }
        defer { fallback.cancel() }

        var delivered = false
        let stream = ImagePipeline.images(for: item.asset, pixelSize: key.pixelSize, allowNetwork: key.allowNetwork)
        for await update in stream {
            delivered = true
            // Nach einem Größenwechsel kein unscharfes Bild über ein schon scharfes legen.
            if update.isDegraded, sharpKey != nil { continue }
            image = update.image
            showsFallback = false
            if !update.isDegraded { sharpKey = key }
        }
        if !delivered, !Task.isCancelled, image == nil {
            showsFallback = true
        }
    }
}

private struct RequestKey: Equatable {
    let itemID: String
    let width: Int
    let height: Int
    let allowNetwork: Bool

    var pixelSize: CGSize { CGSize(width: width, height: height) }
}
