import SQLiteData
import SwiftUI

struct PartyPlayer: Codable, Hashable, Identifiable {
    var name: String
    var score = 0
    /// Sorted by year (by album in an artist pack). Starts with one card, which scores nothing.
    var timeline: [Track]

    var id: String { name }
}

/// A game in progress, saved after every turn so it survives closing the app.
struct PartySave: Codable {
    var datasetID: String
    var players: [PartyPlayer] = []
    /// Card numbers already drawn, so no song comes twice.
    var played: Set<Int> = []
    /// Card number → its track number on the album, from Apple Music. Optional: saves from before it decode.
    var trackNumbers: [Int: Int]?
}

struct NotEnoughSongs: LocalizedError {
    var errorDescription: String? {
        "This song pack has too few songs with a release year for the Party Game."
    }
}

/// The game without cards: the phone draws the songs, players build their timelines on screen.
/// Whoever recognizes a song names it out of three (if that rule is on), then places it:
/// +1 if it fits the timeline, -1 (if that rule is on) and discarded if not. Rules are in Settings.
@MainActor @Observable
final class PartyModel {
    static let saveKey = "partyGame"
    static let defaultWinningScore = 10

    // ponytail: rules are read live, so changing them mid-game applies at once; store them in PartySave if that bites.
    static var winningScore: Int {
        let score = UserDefaults.standard.integer(forKey: SettingsKey.winningScore)
        return score > 0 ? score : defaultWinningScore
    }

    private static func rule(_ key: String) -> Bool {
        UserDefaults.standard.object(forKey: key) as? Bool ?? true
    }

    enum Phase: Hashable {
        case ready, listening, choosing
        /// The song and two others; the player picks which one is playing.
        case naming(player: Int, options: [Track])
        case placing(player: Int)
        /// `player` nil: nobody recognized the song. `slot` nil: the card wasn't placed.
        case revealed(player: Int?, slot: Int?, correct: Bool)
    }

    private(set) var game: PartySave
    private(set) var phase: Phase = .ready
    private(set) var card: Track?
    /// Playback, as in the game with cards.
    let music = GameModel()
    @ObservationIgnored private let deck: [Track]
    /// Artist packs: each album's place in the discography, from the order of the song list.
    /// Nil: cards are placed by year.
    @ObservationIgnored let albumOrder: [String: Int]?

    var winner: PartyPlayer? {
        game.players.first { $0.score >= Self.winningScore }
    }

    private init(game: PartySave, deck: (cards: [Track], albumOrder: [String: Int]?)) {
        self.game = game
        self.deck = deck.cards
        albumOrder = deck.albumOrder
    }

    /// Deals every player a first card.
    static func start(players: [String], datasetID: String) throws -> PartyModel {
        let model = try PartyModel(game: PartySave(datasetID: datasetID), deck: deck(datasetID))
        for name in players {
            guard let card = model.drawCard() else { throw NotEnoughSongs() }
            model.game.players.append(PartyPlayer(name: name, timeline: [card]))
        }
        guard model.deck.count > players.count else { throw NotEnoughSongs() }
        model.persist()
        return model
    }

    /// The saved game; nil if there is none or its dataset was deleted.
    static func resume() -> PartyModel? {
        guard let data = UserDefaults.standard.data(forKey: saveKey),
              let game = try? JSONDecoder().decode(PartySave.self, from: data),
              let deck = try? deck(game.datasetID), !deck.cards.isEmpty
        else { return nil }
        return PartyModel(game: game, deck: deck)
    }

    /// Songs without a year (an album in artist packs) can't be placed.
    private static func deck(_ datasetID: String) throws -> (cards: [Track], albumOrder: [String: Int]?) {
        @Dependency(\.defaultDatabase) var database
        let (tracks, isArtist) = try database.read { db in
            try (Track.where { $0.datasetID.eq(datasetID) }.order(by: \.number).fetchAll(db),
                 Dataset.find(datasetID).fetchOne(db)?.isArtist ?? false)
        }
        guard isArtist else { return (tracks.filter { $0.year != nil }, nil) }
        // Not the year: re-recordings (Taylor's Version) came out later but belong to their era.
        var order: [String: Int] = [:]
        for album in tracks.compactMap(\.album) where order[album] == nil {
            order[album] = order.count
        }
        return (tracks.filter { $0.album != nil }, order)
    }

    /// Where a card goes in a timeline: its year, or its album's place in an artist pack.
    private func position(_ track: Track) -> Int? {
        guard let albumOrder else { return track.year }
        return track.album.flatMap { albumOrder[$0] }
    }

    // MARK: - Turn

    func draw() {
        guard let next = drawCard() else { return }
        card = next
        phase = .listening
        music.play(next)
        persist()
    }

    func choose() {
        phase = .choosing
    }

    func keepListening() {
        phase = .listening
    }

    func recognized(by player: Int?) {
        guard let player else {
            phase = .revealed(player: nil, slot: nil, correct: false)
            return
        }
        // Two other titles, not two versions of one song.
        var titles: Set<String> = [card?.title.lowercased() ?? ""]
        let others = deck.shuffled().filter { titles.insert($0.title.lowercased()).inserted }.prefix(2)
        if Self.rule(SettingsKey.nameTheSong), let card, others.count == 2 {
            phase = .naming(player: player, options: ([card] + others).shuffled())
        } else {
            phase = .placing(player: player)
        }
    }

    /// The right song goes on to placing; a wrong one ends the turn like a wrong placement.
    func name(_ track: Track) {
        guard case let .naming(player, _) = phase else { return }
        if track.number == card?.number {
            phase = .placing(player: player)
        } else {
            penalize(player)
            phase = .revealed(player: player, slot: nil, correct: false)
            persist()
        }
    }

    private func penalize(_ player: Int) {
        if Self.rule(SettingsKey.wrongCostsPoint) {
            game.players[player].score = max(0, game.players[player].score - 1)
        }
    }

    /// `slot`: the gap in the player's timeline, 0 = before the first card.
    func place(at slot: Int) {
        guard case let .placing(player) = phase, let card, let cardPosition = position(card),
              slot <= game.players[player].timeline.count else { return }
        let correct = Self.fits(cardPosition, at: slot, in: game.players[player].timeline.compactMap(position))
        rememberTrackNumber(of: card)
        if correct {
            game.players[player].timeline.insert(card, at: slot)
            game.players[player].score += 1
        } else {
            penalize(player)
        }
        phase = .revealed(player: player, slot: slot, correct: correct)
        persist()
    }

    /// Only from the card's album: a compilation's track number would mislead.
    private func rememberTrackNumber(of card: Track) {
        guard let song = music.song, music.track?.number == card.number, let number = song.trackNumber,
              let album = card.album, song.albumTitle?.localizedCaseInsensitiveContains(album) == true
        else { return }
        var numbers = game.trackNumbers ?? [:]
        numbers[card.number] = number
        game.trackNumbers = numbers
    }

    /// Equal years (or albums) fit on either side.
    nonisolated static func fits(_ year: Int, at slot: Int, in years: [Int]) -> Bool {
        (slot == 0 || years[slot - 1] <= year) && (slot == years.count || year <= years[slot])
    }

    private func drawCard() -> Track? {
        var unplayed = deck.filter { !game.played.contains($0.number) }
        if unplayed.isEmpty {
            // Every song came once: shuffle back all that aren't in a timeline.
            game.played = Set(game.players.flatMap(\.timeline).map(\.number))
            unplayed = deck.filter { !game.played.contains($0.number) }
        }
        guard let card = unplayed.randomElement() else { return nil }
        game.played.insert(card.number)
        return card
    }

    /// A finished game is nothing to continue.
    private func persist() {
        if winner == nil, let data = try? JSONEncoder().encode(game) {
            UserDefaults.standard.set(data, forKey: Self.saveKey)
        } else {
            UserDefaults.standard.removeObject(forKey: Self.saveKey)
        }
    }
}

#if DEBUG
    /// Runs once at launch in debug builds; there is no test target.
    func checkPlacement() {
        let years = [1970, 1985, 1985, 2001]
        assert(PartyModel.fits(1960, at: 0, in: years))
        assert(!PartyModel.fits(1990, at: 0, in: years))
        assert(PartyModel.fits(1985, at: 1, in: years))
        assert(PartyModel.fits(1985, at: 2, in: years))
        assert(PartyModel.fits(1985, at: 3, in: years))
        assert(!PartyModel.fits(1990, at: 2, in: years))
        assert(PartyModel.fits(2020, at: 4, in: years))
        assert(!PartyModel.fits(2000, at: 4, in: years))
        assert(PartyModel.fits(1999, at: 0, in: []))

        // A deck too long for the row: opening any gap keeps every card on screen.
        for open in 0 ... 12 {
            let layout = TimelineRow.layout(count: 12, width: 700, cardWidth: 100, open: open, reservesRoom: true)
            assert(layout.cards.allSatisfy { $0 >= 49.9 && $0 <= 650.1 })
            assert(layout.hole! >= 49.9 && layout.hole! <= 650.1)
            assert(open == 0 || open == 12 || (layout.cards[open - 1] ..< layout.cards[open]).contains(layout.hole!))
        }
    }
#endif
