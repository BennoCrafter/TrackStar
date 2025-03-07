import Combine
import Foundation
import MusicKit
import SwiftData
import SwiftUI

@MainActor
class TrackStarManager: ObservableObject {
    static let shared = TrackStarManager()

    @Published var musicPlayer: MusicPlayerBase = AppleMusicPlayer()
    @Published var song: Song? = nil
    @Published var scannedCodeMetadata: CodeMetadata? = nil
    @Published var isScanning = true
    @Published var activeView: ActiveView = .qrCodeScanning
    @Published var appConfig: AppConfig!
    
    var musicDBManager: MusicDBManager = .shared
    var swiftDataManager: SwiftDataManager = .shared
    
    private var cancellable: AnyCancellable?

    private init() {
        // https://rhonabwy.com/2021/02/13/nested-observable-objects-in-swiftui/
        self.cancellable = self.objectWillChange
            .receive(on: DispatchQueue.main)
            .sink { [weak self] _ in self?.objectWillChange.send()
            }
    }
    
    func configure(with modelContainer: ModelContainer) {
        self.swiftDataManager.configure(with: modelContainer)
        self.musicDBManager.configure(with: self.loadDatabase())
        self.appConfig = self.swiftDataManager.loadAppConfig()
        self.musicPlayer.configureAppConfig(self.appConfig)
    }
    
    func resetQRCode() {
        self.scannedCodeMetadata = nil
        self.isScanning = true
        self.song = nil
        self.musicPlayer.status = .idle
    }
    
    func addCurrentSongToLibrary() async {
        guard let song = song else { return }
        
        do {
            try await MusicLibrary.shared.add(song)
        } catch {
            print("Failed to add song to library")
        }
    }
    
    func fetchSong(from dbSong: DBSong?) async -> Song? {
        guard let dbSong = dbSong else {
            print("Invalid song data.")
            return nil
        }
        var request = MusicCatalogSearchRequest(term: "\(dbSong.title) by \(dbSong.artist)", types: [Song.self])
        request.limit = 1

        do {
            let response = try await request.response()
            if let foundSong = response.songs.first {
                print("Found song: \(foundSong.title) by \(foundSong.artistName)")
                return foundSong
            } else {
                print("Song not found.")
                return nil
            }
        } catch {
            print("Error searching for song: \(error)")
            return nil
        }
    }
    
    func loadDatabase() -> [DBSong] {
        self.swiftDataManager.loadDatabase()
    }
    
    func initNewMusicDatabase(url: URL) -> (Bool, String?) {
        do {
            guard url.startAccessingSecurityScopedResource() else {
                print("Unable to access file securely.")
                return (false, nil)
            }
            
            let data = try Data(contentsOf: url)
            let decoder = JSONDecoder()
            let songs = try decoder.decode([DBSong].self, from: data)
            self.musicDBManager.configure(with: songs)
            self.appConfig.musicDBName = url.lastPathComponent
            
            url.stopAccessingSecurityScopedResource()
            
            self.swiftDataManager.clearMusicDatabase()
            
            self.swiftDataManager.saveMusicDatabase(songs)
            
            return (true, url.lastPathComponent)
        } catch {
            print("Error fetching or decoding data: \(error.localizedDescription)")
            return (false, nil)
        }
    }
    
    func togglePlayState() async {
        switch self.musicPlayer.status {
        case .idle:
            return
        case .playing:
            self.musicPlayer.pauseTimer()
            self.musicPlayer.pause()
        case .paused:
            await self.playSong()
        case .stopped:
            if let song = self.song {
                await self.playSong(song)
                self.musicPlayer.startTimer()
            }
        }
    }
    
    func isPlaying() -> Bool {
        return self.musicPlayer.status == .playing
    }
    
    func playSong(_ song: Song) async {
        await self.musicPlayer.play(song)
        
        let playbackTime = self.appConfig.playbackTimeInterval

        if self.appConfig.useRandomPlaybackInterval {
            await self.musicPlayer.play(song: song, at: song.getRandomPlaybackTime(playbackTimeInterval: playbackTime))
        } else {
            await self.musicPlayer.play(song)
        }
        
        self.musicPlayer.startTimer()
    }
    
    func playSong() async {
        self.musicPlayer.startTimer()
        await self.musicPlayer.play()
    }
}

extension Song {
    func getRandomPlaybackTime(playbackTimeInterval: TimeInterval) -> TimeInterval {
        guard let songDuration = self.duration else { return 0 }
        return TimeInterval.random(in: timeIntervalPadding ... songDuration - playbackTimeInterval - timeIntervalPadding)
    }
}
