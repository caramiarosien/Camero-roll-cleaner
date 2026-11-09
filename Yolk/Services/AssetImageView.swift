import Photos
import SwiftUI

/// Zeigt das Bild eines Eintrags. Platzhalter-Fassung, wird vom Subagenten ersetzt.
/// SCHNITTSTELLE: `AssetImageView(item:targetSize:contentMode:)`
struct AssetImageView: View {
    let item: MediaItem
    var targetSize: CGSize
    var contentMode: ContentMode = .fill

    @State private var image: UIImage?

    var body: some View {
        ZStack {
            Theme.placeholder
            if let image {
                Image(uiImage: image)
                    .resizable()
                    .aspectRatio(contentMode: contentMode)
            }
        }
        .task(id: item.id) {
            let options = PHImageRequestOptions()
            options.deliveryMode = .opportunistic
            options.isNetworkAccessAllowed = true
            let scale = UIScreen.main.scale
            let size = CGSize(width: targetSize.width * scale, height: targetSize.height * scale)
            PHImageManager.default().requestImage(for: item.asset, targetSize: size, contentMode: .aspectFill, options: options) { result, _ in
                if let result { self.image = result }
            }
        }
    }
}
