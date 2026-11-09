import SwiftUI
import CoreText

/// Design-Tokens aus docs/PLAN.md: fast neutral, Royalblau als einzige Farbe, Eigelb nur im Logo.
enum Theme {
    static let background = Color(hex: 0xFAF9F6)
    static let surface = Color.white
    static let ink = Color(hex: 0x151A2B)
    static let inkSecondary = Color(hex: 0x71768A)
    static let line = Color(hex: 0xE8E6E1)
    static let royal = Color(hex: 0x2445C6)
    static let royalSoft = Color(hex: 0xEEF1FB)
    static let yolk = Color(hex: 0xF5BF2A)
    static let placeholder = Color(hex: 0xECEBE7)

    static let cardRadius: CGFloat = 22
    static let tileRadius: CGFloat = 14
}

extension Color {
    init(hex: UInt32) {
        self.init(
            .sRGB,
            red: Double((hex >> 16) & 0xFF) / 255,
            green: Double((hex >> 8) & 0xFF) / 255,
            blue: Double(hex & 0xFF) / 255,
            opacity: 1
        )
    }
}

extension Font {
    /// Überschriften in Instrument Serif. Fällt auf die System-Serifenschrift zurück, falls die Datei fehlt.
    static func display(_ size: CGFloat, italic: Bool = false) -> Font {
        let name = italic ? "InstrumentSerif-Italic" : "InstrumentSerif-Regular"
        if FontRegistrar.isAvailable(name) {
            return .custom(name, size: size, relativeTo: .largeTitle)
        }
        let base = Font.system(size: size, weight: .regular, design: .serif)
        return italic ? base.italic() : base
    }
}

enum FontRegistrar {
    private static var registered = false

    static func registerBundledFonts() {
        guard !registered else { return }
        registered = true
        for name in ["InstrumentSerif-Regular", "InstrumentSerif-Italic"] {
            guard let url = Bundle.main.url(forResource: name, withExtension: "ttf") else { continue }
            CTFontManagerRegisterFontsForURL(url as CFURL, .process, nil)
        }
    }

    static func isAvailable(_ postScriptName: String) -> Bool {
        UIFont(name: postScriptName, size: 12) != nil
    }
}

/// Überschrift mit einem kursiven, royalblauen Wort, wie in den Entwürfen ("Weniger *Ballast.*").
struct DisplayHeadline: View {
    let lead: String
    let accent: String
    var trail: String = ""
    var size: CGFloat = 40

    var body: some View {
        (Text(lead).font(.display(size)).foregroundStyle(Theme.ink)
         + Text(accent).font(.display(size, italic: true)).foregroundStyle(Theme.royal)
         + Text(trail).font(.display(size)).foregroundStyle(Theme.ink))
            .lineSpacing(-4)
            .fixedSize(horizontal: false, vertical: true)
    }
}
