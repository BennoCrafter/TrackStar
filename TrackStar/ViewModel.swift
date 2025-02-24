import Foundation
import MusicKit

class ViewModel: ObservableObject {
    static let shared = ViewModel()
    
    @Published var player = MusicPlayer() // The music player instance
    @Published var song: Song? // Reference to the song
    @Published var scannedCode: String? = nil
    @Published var isScanning = true
    @Published var activeView: ActiveView
    
    var musicDBManager: MusicDBManager = .shared
    
    private init(player: MusicPlayer = MusicPlayer(), song: Song? = nil, scannedCode: String? = nil, isScanning: Bool = true, activeView: ActiveView = ActiveView.qrCodeScanning, musicDBManager: MusicDBManager = .shared) {
        self.player = player
        self.song = song
        self.scannedCode = scannedCode
        self.isScanning = isScanning
        self.activeView = activeView
        self.musicDBManager = musicDBManager
    }
}
