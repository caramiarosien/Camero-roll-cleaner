import Foundation
import SwiftUI

enum Formatting {
    static func bytes(_ value: Int64) -> String {
        ByteCountFormatter.string(fromByteCount: max(0, value), countStyle: .file)
    }

    static func day(_ date: Date?) -> String {
        guard let date else { return "Ohne Datum" }
        return date.formatted(.dateTime.day().month(.wide).year())
    }

    static func duration(_ seconds: TimeInterval) -> String {
        let total = Int(seconds.rounded())
        return String(format: "%d:%02d", total / 60, total % 60)
    }

    static func photos(_ count: Int) -> String {
        count == 1 ? "1 Foto" : "\(count.formatted()) Fotos"
    }
}

/// Kleine Überschrift in Versalien, wie „AUFRÄUMEN“ in den Entwürfen.
struct SectionLabel: View {
    let text: String

    var body: some View {
        Text(text.uppercased())
            .font(.system(size: 11, weight: .medium))
            .tracking(1.4)
            .foregroundStyle(Theme.inkSecondary)
    }
}

/// Hauptknopf als royalblaue Pille.
struct PrimaryButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.system(size: 16, weight: .semibold))
            .foregroundStyle(.white)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 16)
            .background(Theme.royal, in: Capsule())
            .opacity(configuration.isPressed ? 0.85 : 1)
            .scaleEffect(configuration.isPressed ? 0.98 : 1)
            .animation(.easeOut(duration: 0.15), value: configuration.isPressed)
    }
}

/// Zweiter Knopf: nur Text in Royalblau.
struct TextButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.system(size: 15, weight: .medium))
            .foregroundStyle(Theme.royal)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 10)
            .opacity(configuration.isPressed ? 0.6 : 1)
    }
}

/// Hinweisbox auf hellem Blau.
struct NoteBox: View {
    let title: String
    let text: String

    var body: some View {
        (Text(title + " ").font(.system(size: 14, weight: .semibold)).foregroundStyle(Theme.royal)
         + Text(text).font(.system(size: 14)).foregroundStyle(Theme.ink))
            .lineSpacing(3)
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(14)
            .background(Theme.royalSoft, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
    }
}
