import SwiftUI

/// Nach dem Löschen: erklärt, dass der Platz erst nach dem Leeren von „Zuletzt gelöscht“ frei wird.
struct DeletedHintView: View {
    let count: Int
    let bytes: Int64

    @EnvironmentObject private var library: PhotoLibrary
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            DisplayHeadline(lead: "Fast ", accent: "geschafft.", size: 44)
                .padding(.top, 36)

            Text("\(Formatting.photos(count)) mit \(Formatting.bytes(bytes)) liegen jetzt in „Zuletzt gelöscht“. Erst wenn du den Ordner leerst, wird dein iCloud-Speicher frei. Sonst passiert das nach 30 Tagen von selbst.")
                .font(.system(size: 16))
                .foregroundStyle(Theme.inkSecondary)
                .lineSpacing(4)
                .padding(.top, 14)

            VStack(alignment: .leading, spacing: 16) {
                step(1, "Öffne die Fotos-App.")
                step(2, "Scrolle nach unten zu „Zuletzt gelöscht“ (unter „Sonstiges“) und entsperre mit Face ID.")
                step(3, "Tippe auf „Auswählen“ und dann auf „Alle löschen“.")
            }
            .padding(.top, 28)

            Spacer(minLength: 24)

            Button("Fotos öffnen") { library.openPhotosApp() }
                .buttonStyle(PrimaryButtonStyle())
            Button("Später") { dismiss() }
                .buttonStyle(TextButtonStyle())
                .padding(.bottom, 8)
        }
        .padding(.horizontal, 24)
        .background(Theme.background.ignoresSafeArea())
    }

    private func step(_ number: Int, _ text: String) -> some View {
        HStack(alignment: .firstTextBaseline, spacing: 14) {
            Text("\(number)")
                .font(.display(24, italic: true))
                .foregroundStyle(Theme.royal)
                .frame(width: 18)
            Text(text)
                .font(.system(size: 15))
                .foregroundStyle(Theme.ink)
                .fixedSize(horizontal: false, vertical: true)
        }
    }
}
