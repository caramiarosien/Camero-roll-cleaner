import SwiftUI

/// Erster Start: erklärt, was Yolk tut, und fragt nach Zugriff auf die Mediathek.
struct PermissionView: View {
    @EnvironmentObject private var library: PhotoLibrary
    @Binding var continueWithLimited: Bool

    var body: some View {
        ZStack {
            Theme.background.ignoresSafeArea()
            VStack(alignment: .leading, spacing: 0) {
                BrandMark()
                    .padding(.top, 8)

                Spacer(minLength: 24)

                DisplayHeadline(lead: headlineLead, accent: headlineAccent, trail: headlineTrail, size: 46)

                Text(explanation)
                    .font(.system(size: 16))
                    .foregroundStyle(Theme.inkSecondary)
                    .lineSpacing(4)
                    .padding(.top, 16)

                VStack(alignment: .leading, spacing: 14) {
                    promise("lock", "Alles bleibt auf deinem iPhone. Kein Server, kein Upload.")
                    promise("hand.tap", "Gelöscht wird erst, wenn du am Ende bestätigst.")
                    promise("arrow.uturn.backward", "Gelöschtes liegt noch 30 Tage in „Zuletzt gelöscht“.")
                }
                .padding(.top, 28)

                Spacer(minLength: 24)

                actions
            }
            .padding(.horizontal, 24)
            .padding(.bottom, 12)
        }
    }

    // MARK: - Texte je nach Zugriffsstatus

    private var headlineLead: String {
        switch library.access {
        case .denied: return "Kein "
        case .limited: return "Nur ein "
        default: return "Bereit zum\n"
        }
    }

    private var headlineAccent: String {
        switch library.access {
        case .denied: return "Zugriff"
        case .limited: return "Teil"
        default: return "Aufräumen?"
        }
    }

    private var headlineTrail: String {
        switch library.access {
        case .denied: return " auf Fotos."
        case .limited: return " deiner Fotos."
        default: return ""
        }
    }

    private var explanation: String {
        switch library.access {
        case .denied:
            return "Yolk braucht Zugriff auf deine Fotos, um sie dir zum Wischen zu zeigen. Du kannst ihn in den Einstellungen erlauben."
        case .limited:
            return "Du hast Yolk nur ausgewählte Fotos freigegeben. Zum Aufräumen der ganzen Mediathek braucht Yolk vollen Zugriff."
        default:
            return "Wische nach rechts, um ein Foto zu behalten, und nach links, um es loszuwerden. Yolk zeigt dir dafür deine Mediathek."
        }
    }

    @ViewBuilder
    private var actions: some View {
        VStack(spacing: 4) {
            switch library.access {
            case .denied:
                Button("In Einstellungen erlauben") { library.openSettings() }
                    .buttonStyle(PrimaryButtonStyle())
            case .limited:
                Button("Vollen Zugriff erlauben") { library.openSettings() }
                    .buttonStyle(PrimaryButtonStyle())
                Button("Auswahl ändern") { library.presentLimitedLibraryPicker() }
                    .buttonStyle(TextButtonStyle())
                Button("Mit der Auswahl weitermachen") { continueWithLimited = true }
                    .buttonStyle(TextButtonStyle())
            default:
                Button("Zugriff erlauben") {
                    Task { _ = await library.requestAccess() }
                }
                .buttonStyle(PrimaryButtonStyle())
            }
        }
    }

    private func promise(_ symbol: String, _ text: String) -> some View {
        HStack(alignment: .firstTextBaseline, spacing: 12) {
            Image(systemName: symbol)
                .font(.system(size: 15, weight: .regular))
                .foregroundStyle(Theme.royal)
                .frame(width: 20)
            Text(text)
                .font(.system(size: 15))
                .foregroundStyle(Theme.ink)
        }
    }
}

/// Logo: gelber Punkt und „yolk“ in kursiver Serifenschrift.
struct BrandMark: View {
    var body: some View {
        HStack(spacing: 7) {
            Circle().fill(Theme.yolk).frame(width: 10, height: 10)
            Text("yolk")
                .font(.display(28, italic: true))
                .foregroundStyle(Theme.ink)
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("Yolk")
    }
}
