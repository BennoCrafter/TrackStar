import MusicKit
import SQLiteData
import SwiftUI

enum SettingsKey {
    static let hasSeenOnboarding = "hasLaunchedBefore" // name from 1.x, so updaters skip onboarding
    static let playbackDuration = "playbackDuration"
    static let randomStart = "randomStart"
    /// No playback, and the hidden card shows its song.
    static let devMode = "devMode"
}

/// One round: scan a card → listen → reveal → next card.
@MainActor @Observable
final class GameModel {
    enum Phase: Equatable {
        case scanning, loading, listening, revealed
    }

    enum Problem: Identifiable {
        case unknownCode
        case missingDataset(String)
        case missingCard(Int)
        case notFound(Track)
        case message(String)

        var id: String {
            String(describing: self)
        }
    }

    private(set) var phase: Phase = .scanning
    private(set) var track: Track?
    private(set) var song: Song?
    private(set) var elapsed: TimeInterval = 0
    private(set) var isPlaying = false
    /// Shown briefly when a card switched the active dataset.
    private(set) var switchedTo: String?
    var problem: Problem?

    var duration: TimeInterval {
        let value = UserDefaults.standard.double(forKey: SettingsKey.playbackDuration)
        return value > 0 ? value : 30
    }

    /// Where in the song the snippet starts; replay jumps back here.
    @ObservationIgnored private var startOffset: TimeInterval = 0
    @ObservationIgnored private var pendingCode: CardCode?
    @ObservationIgnored private var queuedSong: MusicItemID?
    @ObservationIgnored private var ticker: Task<Void, Never>?
    @ObservationIgnored private let player = ApplicationMusicPlayer.shared

    // MARK: - Scan

    /// A card scanned with the Camera app (`trackstar://…`) replaces the current round.
    func open(_ url: URL) {
        if phase != .scanning { next() }
        scanned(url.absoluteString)
    }

    func scanned(_ string: String) {
        guard phase == .scanning else { return }
        guard let code = CardCode(string) else {
            problem = .unknownCode
            return
        }
        Task { await start(code) }
    }

    private func start(_ code: CardCode) async {
        @Dependency(\.defaultDatabase) var database
        let active = try? await database.read { try Dataset.where(\.isActive).fetchOne($0) }
        guard let datasetID = code.dataset ?? active?.id else {
            problem = .message("Choose a dataset first.")
            return
        }
        guard let dataset = try? await database.read({ try Dataset.find(datasetID).fetchOne($0) }) else {
            pendingCode = code
            problem = .missingDataset(datasetID)
            return
        }
        if !dataset.isActive {
            try? Library.activate(dataset.id)
            showSwitched(to: dataset.displayName)
        }
        guard let track = try? Library.track(dataset: dataset.id, number: code.number) else {
            problem = .missingCard(code.number)
            return
        }
        await start(track)
    }

    /// Plays a card without scanning it (the no-cards mode).
    func play(_ track: Track) {
        Task { await start(track) }
    }

    private func start(_ track: Track) async {
        phase = .loading
        self.track = track
        if UserDefaults.standard.bool(forKey: SettingsKey.devMode) {
            phase = .listening
            return
        }
        guard await MusicAuthorization.request() == .authorized else {
            reset()
            problem = .message("TrackStar needs access to Apple Music to play songs. Allow it in the Settings app.")
            return
        }
        guard let song = await Self.find(track) else {
            phase = .revealed // nothing to play, but the card can still be shown
            problem = .notFound(track)
            return
        }
        self.song = song
        startOffset = randomOffset(in: song)
        phase = .listening
        await play(from: startOffset)
    }

    /// Downloads the dataset of the card that was just scanned, then plays that card.
    func download(_ datasetID: String) async {
        do {
            phase = .loading
            try await Library.install(Library.info(datasetID))
            try Library.activate(datasetID)
            phase = .scanning
            if let pendingCode { await start(pendingCode) }
        } catch {
            phase = .scanning
            problem = .message("Couldn't download “\(datasetID)”: \(error.localizedDescription)")
        }
    }

    private func showSwitched(to name: String) {
        withAnimation { switchedTo = name }
        Task {
            try? await Task.sleep(for: .seconds(2.5))
            withAnimation { switchedTo = nil }
        }
    }

    // MARK: - Playback

    func togglePlayback() {
        if isPlaying {
            pause()
        } else {
            // Past the snippet: play it again instead of continuing.
            let from = elapsed >= duration ? startOffset : startOffset + elapsed
            Task { await play(from: from) }
        }
    }

    func replay() {
        Task { await play(from: startOffset) }
    }

    func reveal() {
        withAnimation(.spring(response: 0.5, dampingFraction: 0.8)) { phase = .revealed }
    }

    /// Back to the scanner for the next card.
    func next() {
        player.stop()
        queuedSong = nil
        reset()
    }

    private func reset() {
        ticker?.cancel()
        isPlaying = false
        elapsed = 0
        track = nil
        song = nil
        withAnimation { phase = .scanning }
    }

    private func play(from offset: TimeInterval) async {
        guard let song else { return }
        do {
            if queuedSong != song.id {
                player.queue = [song]
                queuedSong = song.id
            }
            try await player.prepareToPlay()
            player.playbackTime = offset
            try await player.play()
        } catch {
            problem = .message("Couldn't play the song. Playing needs an Apple Music subscription. (\(error.localizedDescription))")
            return
        }
        isPlaying = true
        elapsed = offset - startOffset
        ticker?.cancel()
        // The player has no snippet end, so poll its position and pause there.
        ticker = Task { [weak self] in
            while !Task.isCancelled {
                try? await Task.sleep(for: .milliseconds(200))
                guard let self, self.isPlaying else { return }
                self.elapsed = max(0, self.player.playbackTime - self.startOffset)
                if self.elapsed >= self.duration {
                    self.elapsed = self.duration
                    // The guessing is over; on the revealed card the song may keep playing.
                    if self.phase == .listening { self.pause() }
                }
            }
        }
    }

    private func pause() {
        player.pause()
        isPlaying = false
        ticker?.cancel()
    }

    private func randomOffset(in song: Song) -> TimeInterval {
        guard UserDefaults.standard.bool(forKey: SettingsKey.randomStart), let length = song.duration else { return 0 }
        // Keep clear of intros and fade-outs.
        let latest = length - duration - 10
        return latest > 10 ? .random(in: 10 ... latest) : 0
    }

    /// The catalog search ranks by popularity, so prefer a result by the card's artist.
    private static func find(_ track: Track) async -> Song? {
        var request = MusicCatalogSearchRequest(term: "\(track.title) \(track.artist)", types: [Song.self])
        request.limit = 5
        guard let songs = try? await request.response().songs else { return nil }
        let artist = track.artist.lowercased()
        return songs.first { song in
            let name = song.artistName.lowercased()
            return name.contains(artist) || artist.contains(name)
        } ?? songs.first
    }
}
