import SwiftUI

/// The game without cards: setup, then the table.
struct PartyView: View {
    let close: () -> Void
    @State private var party: PartyModel?

    init(resume: Bool, close: @escaping () -> Void) {
        self.close = close
        _party = State(initialValue: resume ? PartyModel.resume() : nil)
    }

    var body: some View {
        if let party {
            PartyTableView(party: party) {
                party.music.next()
                close()
            }
        } else {
            PartySetupView(start: { party = $0 }, close: close)
        }
    }
}

/// Played in landscape. Everything scales with the screen, from iPhone to iPad.
struct PartyTableView: View {
    let party: PartyModel
    let close: () -> Void

    @State private var dragOffset: CGSize = .zero
    /// The gap the card is dragged over.
    @State private var target: Int?
    @State private var timelineFrame: CGRect = .zero
    @State private var showingWinner = false
    /// The card bursting out big after a right placement.
    @State private var showingLootbox = false
    /// The song picked while naming, shown right or wrong before the turn goes on.
    @State private var named: Track?

    private static let table = "table"

    private var revealedYear: Int? {
        if case .revealed = party.phase { party.card?.year } else { nil }
    }

    private var activePlayer: Int? {
        switch party.phase {
        case let .naming(player, _): player
        case let .placing(player): player
        case let .revealed(player, _, _): player
        default: nil
        }
    }

    var body: some View {
        ZStack {
            TintedBackground(year: revealedYear)
            GeometryReader { geometry in
                content(geometry.size)
                    .frame(width: geometry.size.width, height: geometry.size.height)
            }
            .padding(.horizontal, 24)
            .padding(.bottom, 8)
            .transition(.blurReplace)
            .id(party.phase)
        }
        .animation(.spring(response: 0.5, dampingFraction: 0.85), value: party.phase)
        .safeAreaInset(edge: .top) { scoreBar }
        .foregroundStyle(.white)
        .overlay {
            if showingLootbox, let card = party.card {
                LootboxReveal(track: card)
                    .onTapGesture {
                        withAnimation(.easeOut(duration: 0.4)) {
                            showingLootbox = false
                            showingWinner = party.winner != nil
                        }
                    }
                    .transition(.opacity)
            }
        }
        .overlay {
            if showingWinner, let winner = party.winner {
                WinnerView(winner: winner, players: party.game.players, finish: close)
                    .transition(.opacity)
            }
        }
        .task(id: party.phase) {
            named = nil
            // A right card bursts out, then the table, or straight the party for the winning card.
            // Everything else flips open on the table.
            guard case let .revealed(_, slot, correct) = party.phase, slot != nil, correct else { return }
            showingLootbox = true
            try? await Task.sleep(for: .seconds(3.5))
            withAnimation(.easeOut(duration: 0.4)) {
                showingLootbox = false
                showingWinner = party.winner != nil
            }
        }
        .environment(\.albumOrder, party.albumOrder)
        .onAppear { AppDelegate.lockLandscape(true) }
        .onDisappear { AppDelegate.lockLandscape(false) }
        .sensoryFeedback(trigger: party.phase) { _, phase in
            if case let .revealed(player, _, correct) = phase, player != nil { return correct ? .success : .error }
            return .impact(weight: .medium)
        }
        .sensoryFeedback(.selection, trigger: target)
        .alert("Can't Play This Song", isPresented: problemBinding, presenting: party.music.problem) { problem in
            Button("OK", role: .cancel) {
                if case .notFound = problem { party.draw() }
            }
        } message: { problem in
            switch problem {
            case let .notFound(track): Text("“\(track.title)” by \(track.artist) isn't on Apple Music. Here comes another song.")
            case let .message(text): Text(text)
            default: Text("Something went wrong.")
            }
        }
    }

    private var problemBinding: Binding<Bool> {
        Binding(get: { party.music.problem != nil }, set: { if !$0 { party.music.problem = nil } })
    }

    // MARK: - Phases

    @ViewBuilder
    private func content(_ size: CGSize) -> some View {
        // Card sizes from the height, which a timeline and the card above it share.
        let unit = min(size.height, size.width * 0.7)
        let titleFont: Font = unit > 450 ? .largeTitle.bold() : .title2.bold()
        switch party.phase {
        case .ready:
            VStack(spacing: 24) {
                Text("First to \(PartyModel.winningScore) points wins").font(titleFont)
                // More songs drawn than the first cards dealt: a saved game going on.
                if party.game.played.count > party.game.players.count {
                    bigButton("Continue", systemImage: "play.fill", action: party.draw)
                } else {
                    bigButton("Start", systemImage: "play.fill", action: party.draw)
                }
            }
        case .listening:
            listening(cardWidth: unit * 0.65, titleFont: titleFont)
        case .choosing:
            chooser(size, titleFont: titleFont)
        case let .naming(player, options):
            naming(player, options: options, titleFont: titleFont)
        case let .placing(player):
            placing(player, unit: unit, titleFont: titleFont)
        case let .revealed(player, slot, correct):
            revealed(player: player, slot: slot, correct: correct, unit: unit, titleFont: titleFont)
        }
    }

    private func listening(cardWidth: CGFloat, titleFont: Font) -> some View {
        VStack(spacing: 16) {
            HStack(spacing: 40) {
                roundButton("gobackward", label: "Replay", action: party.music.replay)
                Button(action: party.choose) {
                    MysteryCard(width: cardWidth, isPlaying: party.music.isPlaying, track: party.card)
                }
                .buttonStyle(.plain)
                .accessibilityLabel("Someone knows the song")
                roundButton(party.music.isPlaying ? "pause.fill" : "play.fill",
                            label: party.music.isPlaying ? "Pause" : "Play",
                            action: party.music.togglePlayback)
            }
            Text("Tap the card when someone knows the song")
                .font(.headline)
                .foregroundStyle(.secondary)
        }
    }

    /// The names fill the screen: few players, huge buttons.
    private func chooser(_ size: CGSize, titleFont: Font) -> some View {
        let count = party.game.players.count
        let columns = count <= 3 ? count : count == 4 ? 2 : count <= 6 ? 3 : 4
        let rows = (count + columns - 1) / columns
        let spacing: CGFloat = 16
        // Minus the title and the button row.
        let available = size.height - 140
        let height = min(max((available - spacing * CGFloat(rows - 1)) / CGFloat(rows), 72), 260)
        return VStack(spacing: spacing) {
            HStack {
                Button(action: party.keepListening) {
                    Label("Keep Listening", systemImage: "chevron.backward")
                        .font(.headline)
                        .padding(.horizontal, 14)
                        .padding(.vertical, 8)
                        .background(.white.opacity(0.12), in: Capsule())
                }
                .buttonStyle(.plain)
                Spacer()
            }
            .overlay { Text("Who knows it?").font(titleFont) }
            ScrollView {
                LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: spacing), count: columns), spacing: spacing) {
                    ForEach(Array(party.game.players.enumerated()), id: \.offset) { index, player in
                        Button { party.recognized(by: index) } label: {
                            Text(player.name)
                                .font(.system(size: min(height * 0.35, 72), weight: .bold, design: .rounded))
                                .lineLimit(1)
                                .minimumScaleFactor(0.4)
                                .padding(.horizontal, 16)
                                .frame(maxWidth: .infinity)
                                .frame(height: height)
                                .background(.white.opacity(0.15), in: RoundedRectangle(cornerRadius: 28, style: .continuous))
                                .contentShape(RoundedRectangle(cornerRadius: 28, style: .continuous))
                        }
                        .buttonStyle(.plain)
                    }
                }
                .frame(maxWidth: 1000)
                .frame(maxWidth: .infinity)
            }
            .scrollBounceBehavior(.basedOnSize)
            Button { party.recognized(by: nil) } label: {
                Label("Nobody Knows It – Reveal", systemImage: "eye.fill")
                    .font(.headline)
                    .padding(.horizontal, 20)
                    .padding(.vertical, 10)
            }
            .buttonStyle(.borderedProminent)
            .buttonBorderShape(.capsule)
            .tint(.orange)
        }
    }

    /// The player says their guess out loud, then taps it here: a green tick or a red cross right away.
    private func naming(_ player: Int, options: [Track], titleFont: Font) -> some View {
        VStack(spacing: 16) {
            Text("\(party.game.players[player].name), what did you guess?").font(titleFont)
            ForEach(options, id: \.number) { option in
                let isPicked = named?.number == option.number
                let isRight = option.number == party.card?.number
                let color: Color = named == nil ? .white.opacity(0.15) : isPicked ? .white.opacity(0.4) : .white.opacity(0.08)
                Button {
                    guard named == nil else { return }
                    named = option
                    Task {
                        try? await Task.sleep(for: .seconds(0.5))
                        party.name(option)
                    }
                } label: {
                    HStack(spacing: 16) {
                        Image(systemName: !isPicked ? "circle" : isRight ? "checkmark.circle.fill" : "xmark.circle.fill")
                            .font(.title)
                            .foregroundStyle(!isPicked ? .white : isRight ? .green : .red)
                            .contentTransition(.symbolEffect(.replace))
                        VStack(alignment: .leading, spacing: 2) {
                            Text(option.title).font(.title3.bold())
                            Text(option.artist).font(.body).foregroundStyle(.secondary)
                        }
                        .lineLimit(1)
                        .minimumScaleFactor(0.6)
                        Spacer(minLength: 0)
                    }
                    .padding(.horizontal, 20)
                    .padding(.vertical, 12)
                    .frame(maxWidth: 700)
                    .background(color, in: RoundedRectangle(cornerRadius: 20, style: .continuous))
                    .contentShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
                }
                .buttonStyle(.plain)
                .animation(.spring(response: 0.3), value: named)
            }
        }
        .frame(maxHeight: .infinity)
        .sensoryFeedback(.selection, trigger: named)
    }

    private func placing(_ player: Int, unit: CGFloat, titleFont: Font) -> some View {
        let timeline = party.game.players[player].timeline
        return VStack(spacing: 16) {
            HStack(spacing: 24) {
                MysteryCard(width: unit * 0.4, isPlaying: party.music.isPlaying, track: party.card)
                    .scaleEffect(dragOffset == .zero ? 1 : 0.8)
                    .offset(dragOffset)
                    .gesture(cardDrag(slots: timeline.count, cardWidth: unit * 0.32))
                    .accessibilityHint("Drag into a gap in your timeline.")
                VStack(alignment: .leading, spacing: 6) {
                    Text("\(party.game.players[player].name), where does it go?").font(titleFont)
                    Text("Drag the card into a gap in your timeline.")
                        .font(unit > 450 ? .title3 : .body)
                        .foregroundStyle(.secondary)
                }
                .frame(maxWidth: 480, alignment: .leading)
            }
            .frame(maxHeight: .infinity)
            .zIndex(1) // the dragged card above the timeline
            TimelineRow(cards: timeline, cardWidth: unit * 0.32, target: target, onPlace: party.place)
            .onGeometryChange(for: CGRect.self) { $0.frame(in: .named(Self.table)) } action: { timelineFrame = $0 }
        }
        .coordinateSpace(.named(Self.table))
    }

    /// No long press: the card moves with the finger at once and lands in the gap below it.
    private func cardDrag(slots: Int, cardWidth: CGFloat) -> some Gesture {
        DragGesture(coordinateSpace: .named(Self.table))
            .onChanged { value in
                dragOffset = value.translation
                target = slot(at: value.location, cards: slots, cardWidth: cardWidth)
            }
            .onEnded { value in
                let slot = slot(at: value.location, cards: slots, cardWidth: cardWidth)
                target = nil
                withAnimation(.spring(response: 0.35, dampingFraction: 0.8)) { dragOffset = .zero }
                if let slot { party.place(at: slot) }
            }
    }

    /// From the closed deck, so the opening gap doesn't move what's under the finger.
    private func slot(at point: CGPoint, cards: Int, cardWidth: CGFloat) -> Int? {
        guard timelineFrame.insetBy(dx: 0, dy: -timelineFrame.height * 0.5).contains(point) else { return nil }
        let x = point.x - timelineFrame.minX
        return TimelineRow.layout(count: cards, width: timelineFrame.width, cardWidth: cardWidth, open: nil, reservesRoom: false)
            .cards.filter { $0 < x }.count
    }

    @ViewBuilder
    private func revealed(player: Int?, slot: Int?, correct: Bool, unit: CGFloat, titleFont: Font) -> some View {
        if let card = party.card {
            VStack(spacing: 16) {
                HStack(spacing: 24) {
                    // A wrong guess just shows the song: no flip, no timeline.
                    if player != nil, slot == nil {
                        MiniCard(track: card, width: unit * 0.6)
                    } else {
                        FlipCard(track: card, width: unit * (player == nil ? 0.6 : 0.4))
                    }
                    VStack(alignment: .leading, spacing: 12) {
                        result(player: player, correct: correct, wasPlaced: slot != nil, font: titleFont)
                        if let winner = party.winner {
                            Label("\(winner.name) wins!", systemImage: "trophy.fill")
                                .font(.largeTitle.bold())
                                .foregroundStyle(.yellow)
                            bigButton("Finish", systemImage: "flag.checkered", action: close)
                        } else {
                            bigButton("Next Song", systemImage: "forward.fill", action: party.draw)
                        }
                    }
                    .frame(maxWidth: 480, alignment: .leading)
                }
                .frame(maxHeight: .infinity)
                if let player, let slot {
                    // A wrong card is shown where it was put, then gone with the next song.
                    let timeline = party.game.players[player].timeline
                    TimelineRow(
                        cards: correct ? timeline : timeline.inserting(card, at: slot),
                        cardWidth: unit * 0.32,
                        placed: (card.number, correct))
                }
            }
        }
    }

    @ViewBuilder
    private func result(player: Int?, correct: Bool, wasPlaced: Bool, font: Font) -> some View {
        if let player {
            let name = party.game.players[player].name
            let wrong: LocalizedStringKey = wasPlaced ? "Wrong spot" : "Wrong song"
            if correct {
                Label("Right! +1 for \(name)", systemImage: "checkmark.circle.fill")
                    .font(font).foregroundStyle(.green)
            } else if UserDefaults.standard.object(forKey: SettingsKey.wrongCostsPoint) as? Bool ?? true {
                Label("\(Text(wrong)). −1 for \(name)", systemImage: "xmark.circle.fill")
                    .font(font).foregroundStyle(.red)
            } else {
                Label("\(Text(wrong)), \(name)", systemImage: "xmark.circle.fill")
                    .font(font).foregroundStyle(.red)
            }
        } else {
            Text("Nobody knew it").font(font)
        }
    }

    // MARK: - Parts

    private var scoreBar: some View {
        HStack(spacing: 12) {
            Button(action: close) {
                Image(systemName: "xmark")
                    .font(.headline)
                    .frame(width: 36, height: 36)
                    .background(.white.opacity(0.15), in: Circle())
            }
            .accessibilityLabel("Leave game")
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 8) {
                    ForEach(Array(party.game.players.enumerated()), id: \.offset) { index, player in
                        HStack(spacing: 6) {
                            Text(player.name).lineLimit(1)
                            Text("\(player.score)")
                                .monospacedDigit()
                                .contentTransition(.numericText())
                                .fontWeight(.black)
                        }
                        .font(.subheadline.weight(.semibold))
                        .padding(.horizontal, 12)
                        .padding(.vertical, 8)
                        .background(.white.opacity(index == activePlayer ? 0.35 : 0.12), in: Capsule())
                    }
                }
            }
        }
        .buttonStyle(.plain)
        .padding(.horizontal, 24)
        .padding(.top, 8)
    }

    private func bigButton(_ title: LocalizedStringKey, systemImage: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Label(title, systemImage: systemImage)
                .font(.title2.bold())
                .padding(.horizontal, 32)
                .padding(.vertical, 12)
        }
        .buttonStyle(.borderedProminent)
        .buttonBorderShape(.capsule)
        .tint(.white)
        .foregroundStyle(.black)
    }

    private func roundButton(_ systemImage: String, label: LocalizedStringKey, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Image(systemName: systemImage)
                .font(.title2.weight(.semibold))
                .contentTransition(.symbolEffect(.replace))
                .frame(width: 64, height: 64)
                .background(.white.opacity(0.15), in: Circle())
        }
        .buttonStyle(.plain)
        .accessibilityLabel(label)
    }
}

/// A player's cards by year, laid out like a deck on a table: side by side while they fit,
/// fanned and overlapping when there are many, using the whole width. While the card is dragged
/// over them, they squeeze together and part where it would go.
struct TimelineRow: View {
    let cards: [Track]
    let cardWidth: CGFloat
    var target: Int?
    /// Set while placing.
    var onPlace: ((Int) -> Void)?
    /// The card just placed, flipped open and marked right or wrong.
    var placed: (number: Int, correct: Bool)?

    private static let spacing: CGFloat = 12

    var body: some View {
        GeometryReader { geometry in
            let width = geometry.size.width
            let layout = Self.layout(count: cards.count, width: width, cardWidth: cardWidth,
                                     open: onPlace == nil ? nil : target, reservesRoom: onPlace != nil && target != nil)
            ZStack(alignment: .topLeading) {
                if let hole = layout.hole {
                    RoundedRectangle(cornerRadius: cardWidth * 0.12, style: .continuous)
                        .strokeBorder(style: StrokeStyle(lineWidth: 3, dash: [8]))
                        .foregroundStyle(.white.opacity(0.8))
                        .frame(width: cardWidth, height: cardWidth)
                        .position(x: hole, y: fanY(hole, width: width))
                        .transition(.opacity)
                }
                ForEach(Array(cards.enumerated()), id: \.element.number) { index, card in
                    let x = layout.cards[index]
                    cardView(card)
                        .shadow(color: .black.opacity(0.4), radius: 8, x: -3, y: 2)
                        .rotationEffect(.degrees((x - width / 2) / width * 10))
                        .position(x: x, y: fanY(x, width: width))
                        .zIndex(placed?.number == card.number ? 1 : 0)
                }
            }
            .animation(.spring(response: 0.3, dampingFraction: 0.8), value: target)
        }
        .frame(height: cardWidth * 1.1)
        .accessibilityElement(children: .contain)
        .accessibilityActions {
            if let onPlace {
                ForEach(0 ... cards.count, id: \.self) { slot in
                    Button(slot == 0 ? "Place before \(cards[0].title)" : "Place after \(cards[slot - 1].title)") { onPlace(slot) }
                }
            }
        }
    }

    @ViewBuilder
    private func cardView(_ card: Track) -> some View {
        if let placed, placed.number == card.number {
            FlipCard(track: card, width: cardWidth)
                .overlay {
                    RoundedRectangle(cornerRadius: cardWidth * 0.12, style: .continuous)
                        .strokeBorder(placed.correct ? .green : .red, lineWidth: 4)
                }
        } else {
            MiniCard(track: card, width: cardWidth)
        }
    }

    /// The outer cards sit a little lower, like a fanned hand.
    private func fanY(_ x: CGFloat, width: CGFloat) -> CGFloat {
        let fromCenter = (x - width / 2) / (width / 2)
        return cardWidth / 2 + fromCenter * fromCenter * cardWidth * 0.08
    }

    /// Card centers and the center of the opened gap. `open`: the gap the dragged card is over.
    /// `reservesRoom`: squeezes the deck so the opened gap never pushes cards off screen.
    static func layout(count: Int, width: CGFloat, cardWidth w: CGFloat, open: Int?, reservesRoom: Bool) -> (cards: [CGFloat], hole: CGFloat?) {
        let s = spacing
        var step: CGFloat = 0
        if count > 1 {
            let fit = reservesRoom
                ? (count > 2 ? (width - 3 * w - 2 * s) / CGFloat(count - 2) : w + s)
                : (width - w) / CGFloat(count - 1)
            step = max(min(w + s, fit), 10)
        }
        let total = w + step * CGFloat(count - 1)
        var xs = (0 ..< count).map { (width - total) / 2 + w / 2 + step * CGFloat($0) }
        guard let open, count > 0 else { return (xs, nil) }
        // In the middle, neighbors end up a card and two spacings apart, however tight the deck.
        // At an end, the deck only moves over by half a card.
        let shift = open == 0 || open == count ? (w + s) / 2 : (2 * w + 2 * s - step) / 2
        for i in xs.indices {
            xs[i] += i < open ? -shift : shift
        }
        let hole = open == 0 ? xs[0] - w - s
            : open == count ? xs[count - 1] + w + s
            : (xs[open - 1] + xs[open]) / 2
        return (xs, hole)
    }
}

extension EnvironmentValues {
    /// Artist packs: each album's place in the discography. Cards show and are placed by album.
    @Entry var albumOrder: [String: Int]?
}

/// A song card in the timeline: artist, year, title on its period's gradient.
/// In an artist pack: year, album, title, and dots for where the album is in the discography, in a color per album.
struct MiniCard: View {
    let track: Track
    let width: CGFloat
    @Environment(\.albumOrder) private var albumOrder

    private var byAlbum: Bool { albumOrder != nil }
    private var albumIndex: Int? { track.album.flatMap { albumOrder?[$0] } }

    /// A period's colors per album: the first album gets the 1950s', the next the late 50s' and so on.
    private var colorYear: Int? {
        albumIndex.map { 1950 + $0 * 5 } ?? track.year
    }

    var body: some View {
        VStack(spacing: width * 0.04) {
            Text(byAlbum ? track.year.map(String.init) ?? "" : track.artist)
                .font(.system(size: width * 0.1, weight: .semibold))
                .lineLimit(2)
            Spacer(minLength: 0)
            if byAlbum {
                Text(track.album ?? "?")
                    .font(.system(size: width * 0.15, weight: .black, design: .rounded))
                    .lineLimit(3)
            } else {
                Text(track.year.map(String.init) ?? "?")
                    .font(.system(size: width * 0.3, weight: .black, design: .rounded))
                    .lineLimit(1)
            }
            Spacer(minLength: 0)
            Text(track.title)
                .font(.system(size: width * 0.1, weight: .bold))
                .lineLimit(2)
            if let albumOrder, let albumIndex {
                // Shrinks to fit 15+ albums in the card.
                let dot = width * min(0.045, 0.55 / CGFloat(albumOrder.count))
                HStack(spacing: dot / 2) {
                    ForEach(0 ..< albumOrder.count, id: \.self) { index in
                        Circle()
                            .fill(.white.opacity(index == albumIndex ? 1 : 0.3))
                            .frame(width: dot)
                    }
                }
                .accessibilityLabel("Album \(albumIndex + 1) of \(albumOrder.count)")
            }
        }
        .minimumScaleFactor(0.6)
        .multilineTextAlignment(.center)
        .foregroundStyle(.white)
        .padding(width * 0.08)
        .frame(width: width, height: width)
        .background(PeriodGradient.gradient(for: colorYear), in: RoundedRectangle(cornerRadius: width * 0.12, style: .continuous))
        .accessibilityElement(children: .combine)
    }
}

/// The face-down card of the song that's playing.
struct MysteryCard: View {
    let width: CGFloat
    var isPlaying = false
    /// Shown in developer mode.
    var track: Track?
    @AppStorage(SettingsKey.devMode) private var devMode = false

    var body: some View {
        Image(systemName: "questionmark")
            .font(.system(size: width * 0.45, weight: .black))
            .foregroundStyle(.white)
            .frame(width: width, height: width)
            .background(
                LinearGradient(colors: [.accentColor, .accentColor.opacity(0.45)], startPoint: .topLeading, endPoint: .bottomTrailing),
                in: RoundedRectangle(cornerRadius: width * 0.12, style: .continuous))
            .overlay {
                RoundedRectangle(cornerRadius: width * 0.12, style: .continuous)
                    .strokeBorder(.white.opacity(0.3), lineWidth: 1)
            }
            .overlay(alignment: .bottom) {
                if devMode, let track {
                    Text("\(track.artist) – \(track.title) · \(track.year.map(String.init) ?? "?")")
                        .font(.system(size: max(10, width * 0.06), weight: .semibold))
                        .multilineTextAlignment(.center)
                        .lineLimit(3)
                        .minimumScaleFactor(0.6)
                        .foregroundStyle(.white.opacity(0.9))
                        .padding(width * 0.06)
                } else {
                    Image(systemName: "waveform")
                        .font(.system(size: width * 0.12, weight: .semibold))
                        .symbolEffect(.variableColor.iterative.dimInactiveLayers, isActive: isPlaying)
                        .foregroundStyle(.white.opacity(0.8))
                        .padding(width * 0.08)
                }
            }
            .shadow(color: .accentColor.opacity(0.4), radius: 20, y: 10)
    }
}

/// Turns from the question mark to the song as soon as it appears.
struct FlipCard: View {
    let track: Track
    let width: CGFloat
    @State private var isFlipped = false

    var body: some View {
        ZStack {
            MiniCard(track: track, width: width)
                .rotation3DEffect(.degrees(isFlipped ? 0 : -180), axis: (0, 1, 0))
                .opacity(isFlipped ? 1 : 0)
            MysteryCard(width: width)
                .rotation3DEffect(.degrees(isFlipped ? 180 : 0), axis: (0, 1, 0))
                .opacity(isFlipped ? 0 : 1)
        }
        .onAppear {
            withAnimation(.spring(response: 0.7, dampingFraction: 0.8).delay(0.3)) { isFlipped = true }
        }
    }
}

private extension Array {
    func inserting(_ element: Element, at index: Int) -> Self {
        var copy = self
        copy.insert(element, at: index)
        return copy
    }
}

/// A right card bursts out like a loot box: light rays in its period color, a spin from face down to the song, big.
struct LootboxReveal: View {
    let track: Track

    @State private var isOpen = false
    @State private var raysTurn = false

    private var glow: Color { PeriodGradient.colors(for: track.year).0 }

    var body: some View {
        GeometryReader { geometry in
            let width = min(geometry.size.width, geometry.size.height) * 0.6
            ZStack {
                Color.black.opacity(0.7)
                AngularGradient(colors: Array(repeating: [glow.opacity(0.7), .clear], count: 8).flatMap { $0 }, center: .center)
                    .frame(width: width * 3, height: width * 3)
                    .mask(RadialGradient(colors: [.white, .clear], center: .center, startRadius: 0, endRadius: width * 1.5))
                    .rotationEffect(.degrees(raysTurn ? 360 : 0))
                    .scaleEffect(isOpen ? 1 : 0.2)
                    .opacity(isOpen ? 1 : 0)
                SpinningCard(track: track, width: width, angle: isOpen ? 0 : -720)
                    .scaleEffect(isOpen ? 1 : 0.1)
                    .shadow(color: glow.opacity(0.8), radius: isOpen ? 40 : 0)
            }
            .frame(width: geometry.size.width, height: geometry.size.height)
        }
        .ignoresSafeArea()
        .contentShape(Rectangle())
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(track.title) by \(track.artist), \(track.year.map(String.init) ?? "")")
        .onAppear {
            withAnimation(.spring(response: 2.2, dampingFraction: 0.85)) { isOpen = true }
            withAnimation(.linear(duration: 12).repeatForever(autoreverses: false)) { raysTurn = true }
        }
    }
}

/// Face down while its back points at the viewer, the song once it turns around.
private struct SpinningCard: View, Animatable {
    let track: Track
    let width: CGFloat
    var angle: Double

    nonisolated var animatableData: Double {
        get { angle }
        set { angle = newValue }
    }

    var body: some View {
        Group {
            if cos(angle * .pi / 180) >= 0 {
                MiniCard(track: track, width: width)
            } else {
                MysteryCard(width: width).scaleEffect(x: -1) // unmirror the back
            }
        }
        .rotation3DEffect(.degrees(angle), axis: (0, 1, 0), perspective: 0.4)
    }
}
