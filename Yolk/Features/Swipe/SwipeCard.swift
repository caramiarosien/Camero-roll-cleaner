import SwiftUI

/// Eine Karte im Stapel. Kippt beim Ziehen und zeigt „Behalten“ oder „Weg“.
struct SwipeCard: View {
    let item: MediaItem
    let size: CGSize
    var offset: CGSize = .zero
    /// Ab dieser Verschiebung gilt ein Wisch als Entscheidung.
    var threshold: CGFloat = 110

    var body: some View {
        AssetImageView(item: item, targetSize: size)
            .frame(width: size.width, height: size.height)
            .clipShape(RoundedRectangle(cornerRadius: Theme.cardRadius, style: .continuous))
            .overlay(alignment: .topLeading) {
                stamp("Behalten", background: Theme.royal)
                    .rotationEffect(.degrees(-10))
                    .padding(20)
                    .opacity(progress(towards: 1))
            }
            .overlay(alignment: .topTrailing) {
                stamp("Weg", background: Theme.ink)
                    .rotationEffect(.degrees(10))
                    .padding(20)
                    .opacity(progress(towards: -1))
            }
            .overlay(alignment: .bottomLeading) {
                if item.isVideo { videoBadge.padding(14) }
            }
            .shadow(color: Theme.ink.opacity(0.12), radius: 18, x: 0, y: 10)
            .offset(offset)
            .rotationEffect(.degrees(Double(offset.width / 22)), anchor: .bottom)
            .accessibilityElement(children: .ignore)
            .accessibilityLabel(item.isVideo ? "Video" : "Foto")
            .accessibilityValue(Formatting.day(item.creationDate))
    }

    private func progress(towards direction: CGFloat) -> Double {
        let value = offset.width * direction / threshold
        return Double(min(max(value, 0), 1))
    }

    private func stamp(_ text: String, background: Color) -> some View {
        Text(text)
            .font(.display(28, italic: true))
            .foregroundStyle(.white)
            .padding(.horizontal, 16)
            .padding(.top, 2)
            .padding(.bottom, 5)
            .background(background, in: Capsule())
    }

    private var videoBadge: some View {
        HStack(spacing: 5) {
            Image(systemName: "play.fill").font(.system(size: 10, weight: .bold))
            Text(Formatting.duration(item.duration)).font(.system(size: 12, weight: .semibold)).monospacedDigit()
        }
        .foregroundStyle(.white)
        .padding(.horizontal, 10)
        .padding(.vertical, 6)
        .background(.black.opacity(0.45), in: Capsule())
    }
}
