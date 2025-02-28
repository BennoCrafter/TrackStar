import Foundation
import MusicKit
import SwiftData
import SwiftUI

@MainActor
class TrackStarManager: ObservableObject {
    static let shared = TrackStarManager()
    @AppStorage("musicDBName") var musicDBName: String = ""

    @ObservedObject var musicPlayer = MusicPlayer()
    @Published var song: Song? = nil
    @Published var scannedCode: String? = nil
    @Published var isScanning = true
    @Published var activeView: ActiveView = .qrCodeScanning
    
    var musicDBManager: MusicDBManager = .shared
    var swiftDataManager: SwiftDataManager = .shared
    
    private init() {}
    
    func configure(with modelContainer: ModelContainer) {
        self.swiftDataManager.configure(with: modelContainer)
        self.musicDBManager.configure(with: self.loadDatabase())
    }
    
    func resetQRCode() {
        self.scannedCode = nil
        self.isScanning = true
        self.musicPlayer.stop()
        self.song = nil
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
            self.musicDBName = url.lastPathComponent
            
            url.stopAccessingSecurityScopedResource()
            
            self.swiftDataManager.saveDatabase(songs)
            
            return (true, url.lastPathComponent)
        } catch {
            print("Error fetching or decoding data: \(error.localizedDescription)")
            return (false, nil)
        }
    }
    
    func togglePlayState() async {
        if self.musicPlayer.status == .playing {
            self.musicPlayer.pause()
        } else {
            await self.musicPlayer.play()
        }
    }
    
    func isPlaying() -> Bool {
        return self.musicPlayer.status == .playing
    }
}
