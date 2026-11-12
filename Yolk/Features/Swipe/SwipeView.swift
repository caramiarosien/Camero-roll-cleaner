import SwiftData
import SwiftUI

/// Der Wisch-Bildschirm für „Alle Fotos“: rechts behalten, links in den Papierkorb.
struct SwipeView: View {
    @EnvironmentObject private var library: PhotoLibrary
    @Environment(\.modelContext) private var context
    @Environment(\.dismiss) private var dismiss
    @Environment(\.scenePhase) private var scenePhase
    @EnvironmentObject private var navigator: Navigator
    @StateObject private var session = SwipeSession(library: .shared)
    @Query(filter: #Predicate<Decision> { $0.kindRaw == "trash" }) private var trashed: [Decision]

    @State private var offset: CGSize = .zero
    @State private var isFlying = false
    @State private var decisionTick = 0

    private let threshold: CGFloat = 110

    var body: some View {
        VStack(spacing: 0) {
            header
            progressBar
                .padding(.top, 12)
            GeometryReader { geo in
                cardStack(in: geo.size)
                    .frame(width: geo.size.width, height: geo.size.height)
            }
            .padding(.top, 18)
            meta
                .padding(.top, 12)
            controls
                .padding(.top, 14)
                .padding(.bottom, 8)
        }
        .padding(.horizontal, 20)
        .background(Theme.background.ignoresSafeArea())
        .toolbar(.hidden, for: .navigationBar)
        .sensoryFeedback(.impact(weight: .medium), trigger: decisionTick)
        .onAppear {
            session.attach(context)
            if session.isLoaded {
                session.pruneMissing() // zurück aus dem Papierkorb: gelöschte Fotos raus
            } else {
                session.load()
            }
        }
        .onDisappear { library.resetCaching() }
        .onChange(of: library.changeToken) { _, _ in session.pruneMissing() }
        .onChange(of: scenePhase) { _, _ in
            // Ein abgebrochener Wisch (Anruf, Kontrollzentrum) ruft kein onEnded auf.
            if !isFlying, offset != .zero {
                withAnimation(.spring(response: 0.35, dampingFraction: 0.7)) { offset = .zero }
            }
        }
    }

    // MARK: - Kopfzeile

    private var header: some View {
        HStack {
            Button { dismiss() } label: {
                Image(systemName: "chevron.left")
                    .font(.system(size: 18, weight: .medium))
                    .foregroundStyle(Theme.ink)
                    .frame(width: 36, height: 36, alignment: .leading)
            }
            .accessibilityLabel("Zurück")

            Spacer()

            Text("Alle Fotos")
                .font(.display(26))
                .foregroundStyle(Theme.ink)

            Spacer()

            Button { navigator.open(.trash) } label: {
                HStack(spacing: 5) {
                    Image(systemName: "trash").font(.system(size: 13, weight: .medium))
                    Text("\(trashed.count)").font(.system(size: 13, weight: .semibold)).monospacedDigit()
                }
                .foregroundStyle(trashed.isEmpty ? Theme.inkSecondary : Theme.royal)
                .padding(.horizontal, 10)
                .frame(height: 30)
                .background(trashed.isEmpty ? Theme.surface : Theme.royalSoft, in: Capsule())
                .overlay(Capsule().stroke(Theme.line, lineWidth: trashed.isEmpty ? 1 : 0))
            }
            .accessibilityLabel("Papierkorb, \(trashed.count) Fotos")
        }
    }

    private var progressBar: some View {
        GeometryReader { geo in
            let fraction = session.total == 0 ? 0 : CGFloat(session.position) / CGFloat(session.total)
            ZStack(alignment: .leading) {
                Capsule().fill(Theme.line)
                Capsule().fill(Theme.royal).frame(width: geo.size.width * fraction)
            }
        }
        .frame(height: 3)
        .animation(.easeOut(duration: 0.25), value: session.position)
    }

    // MARK: - Kartenstapel

    @ViewBuilder
    private func cardStack(in size: CGSize) -> some View {
        let cards = session.upcoming(3)
        if !session.isLoaded {
            ProgressView().tint(Theme.royal)
        } else if cards.isEmpty {
            emptyState
        } else {
            let cardSize = CGSize(width: size.width * 0.92, height: size.height)
            ZStack {
                ForEach(Array(cards.enumerated().reversed()), id: \.element.id) { index, item in
                    SwipeCard(item: item, size: cardSize, offset: index == 0 ? offset : .zero, threshold: threshold)
                        .scaleEffect(index == 0 ? 1 : 1 - CGFloat(index) * 0.05, anchor: .bottom)
                        .offset(y: CGFloat(index) * -10)
                        .opacity(index >= 2 ? 0 : 1)
                        .allowsHitTesting(index == 0)
                        .gesture(dragGesture, including: index == 0 ? .all : .none)
                        .transition(.asymmetric(insertion: .scale(scale: 0.95).combined(with: .opacity), removal: .identity))
                }
            }
            .animation(.spring(response: 0.35, dampingFraction: 0.8), value: session.position)
            .onAppear { prefetch(cardSize) }
            .onChange(of: session.position) { _, _ in prefetch(cardSize) }
        }
    }

    /// Lädt die nächsten Karten in derselben Größe vor, in der `SwipeCard` sie anfordert.
    private func prefetch(_ cardSize: CGSize) {
        if let passed = session.lastDecided {
            library.stopCaching([passed], targetSize: cardSize)
        }
        library.startCaching(session.upcoming(6), targetSize: cardSize)
    }

    private var dragGesture: some Gesture {
        DragGesture()
            .onChanged { value in
                guard !isFlying else { return }
                offset = value.translation
            }
            .onEnded { value in
                guard !isFlying else { return }
                let width = value.translation.width
                let predicted = value.predictedEndTranslation.width
                if width > threshold || predicted > 420 {
                    commit(.keep)
                } else if width < -threshold || predicted < -420 {
                    commit(.trash)
                } else {
                    withAnimation(.spring(response: 0.35, dampingFraction: 0.7)) { offset = .zero }
                }
            }
    }

    private func commit(_ kind: DecisionKind) {
        guard session.current != nil, !isFlying else { return }
        isFlying = true
        let direction: CGFloat = kind == .trash ? -1 : 1
        withAnimation(.easeIn(duration: 0.2)) {
            offset = CGSize(width: direction * 700, height: offset.height + 60)
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
            var reset = Transaction()
            reset.disablesAnimations = true
            withTransaction(reset) { offset = .zero }
            session.decide(kind)
            decisionTick += 1
            isFlying = false
        }
    }

    private var emptyState: some View {
        VStack(spacing: 18) {
            DisplayHeadline(lead: "Alles ", accent: "gesichtet.", size: 40)
                .multilineTextAlignment(.center)
            Text(trashed.isEmpty
                 ? "Du hast jedes Foto einmal gesehen."
                 : "Jetzt noch den Papierkorb prüfen und einmal bestätigen.")
                .font(.system(size: 15))
                .foregroundStyle(Theme.inkSecondary)
                .multilineTextAlignment(.center)
            if !trashed.isEmpty {
                Button("Zum Papierkorb") { navigator.open(.trash) }
                    .buttonStyle(PrimaryButtonStyle())
                    .padding(.horizontal, 30)
            }
        }
        .padding(.horizontal, 10)
    }

    // MARK: - Unter der Karte

    private var meta: some View {
        HStack {
            if let item = session.current {
                Text(Formatting.day(item.creationDate))
                    .foregroundStyle(Theme.ink)
                Spacer()
                Text(Formatting.bytes(library.byteSize(of: item)))
                    .foregroundStyle(Theme.inkSecondary)
                    .monospacedDigit()
            } else {
                Spacer()
            }
        }
        .font(.system(size: 13))
        .padding(.horizontal, 12)
        .frame(height: 18)
    }

    private var controls: some View {
        HStack(spacing: 22) {
            CircleButton(symbol: "arrow.uturn.backward", size: 46, label: "Rückgängig") {
                withAnimation(.spring(response: 0.35, dampingFraction: 0.8)) { session.undo() }
            }
            .disabled(!session.canUndo || isFlying)
            .opacity(session.canUndo ? 1 : 0.4)

            CircleButton(symbol: "xmark", size: 68, label: "Weg") { commit(.trash) }
                .disabled(session.current == nil)

            CircleButton(symbol: "checkmark", size: 68, filled: true, label: "Behalten") { commit(.keep) }
                .disabled(session.current == nil)

            Color.clear.frame(width: 46, height: 46)
        }
    }
}

/// Runder Knopf wie in den Entwürfen: weiß mit feiner Linie oder royalblau gefüllt.
struct CircleButton: View {
    let symbol: String
    let size: CGFloat
    var filled = false
    let label: String
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Image(systemName: symbol)
                .font(.system(size: size * 0.34, weight: filled ? .semibold : .regular))
                .foregroundStyle(filled ? .white : Theme.ink)
                .frame(width: size, height: size)
                .background(filled ? Theme.royal : Theme.surface, in: Circle())
                .overlay(Circle().stroke(filled ? Color.clear : Theme.line, lineWidth: 1))
        }
        .buttonStyle(PressScaleStyle())
        .accessibilityLabel(label)
    }
}

struct PressScaleStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? 0.92 : 1)
            .animation(.spring(response: 0.25, dampingFraction: 0.6), value: configuration.isPressed)
    }
}
