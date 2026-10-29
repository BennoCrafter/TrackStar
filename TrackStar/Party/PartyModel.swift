import SQLiteData
import SwiftUI

struct PartyPlayer: Codable, Hashable, Identifiable {
    var name: String
    var score = 0
    /// Sorted by year. Starts with one card, which scores nothing.
    var timeline: [Track]

    var id: String { name }
}

/// A game in progress, saved after every turn so it survives closing the app.
struct PartySave: Codable {
    var datasetID: String
    var players: [PartyPlayer] = []
    /// Card numbers already drawn, so no song comes twice.
    var played: Set<Int> = []
}

struct NotEnoughSongs: LocalizedError {
    var errorDescription: String? {
        "This dataset has too few songs with a release year to play without cards."
    }
}

/// The game without cards: the phone draws the songs, players build their timelines on screen.
/// Whoever recognizes a song places it: +1 if it fits the timeline, -1 and discarded if not.
@MainActor @Observable
final class PartyModel {
    static let saveKey = "partyGame"
    static let winningScore = 10

    enum Phase: Hashable {
        case ready, listening, choosing
        case placing(player: Int)
        /// `player` nil: nobody recognized the song.
        case revealed(player: Int?, slot: Int, correct: Bool)
    }

    private(set) var game: PartySave
    private(set) var phase: Phase = .ready
    private(set) var card: Track?
    /// Playback, as in the game with cards.
    let music = GameModel()
    @ObservationIgnored private let deck: [Track]

    var winner: PartyPlayer? {
        game.players.first { $0.score >= Self.winningScore }
    }

    private init(game: PartySave, deck: [Track]) {
        self.game = game
        self.deck = deck
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
              let deck = try? deck(game.datasetID), !deck.isEmpty
        else { return nil }
        return PartyModel(game: game, deck: deck)
    }

    /// Songs without a year can't be placed.
    private static func deck(_ datasetID: String) throws -> [Track] {
        @Dependency(\.defaultDatabase) var database
        return try database.read { db in
            try Track.where { $0.datasetID.eq(datasetID) }.fetchAll(db)
        }
        .filter { $0.year != nil }
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
        if let player {
            phase = .placing(player: player)
        } else {
            phase = .revealed(player: nil, slot: 0, correct: false)
        }
    }

    /// `slot`: the gap in the player's timeline, 0 = before the first card.
    func place(at slot: Int) {
        guard case let .placing(player) = phase, let card, let year = card.year,
              slot <= game.players[player].timeline.count else { return }
        let correct = Self.fits(year, at: slot, in: game.players[player].timeline.compactMap(\.year))
        if correct {
            game.players[player].timeline.insert(card, at: slot)
            game.players[player].score += 1
        } else {
            game.players[player].score = max(0, game.players[player].score - 1)
        }
        phase = .revealed(player: player, slot: slot, correct: correct)
        persist()
    }

    /// Equal years fit on either side.
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
