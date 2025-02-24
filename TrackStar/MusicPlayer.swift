import Foundation
import MusicKit

enum MusicStatus {
    case playing, paused, stopped, idle
}

class MusicPlayer: ObservableObject {
    private var aMusicPlayer: ApplicationMusicPlayer = .shared
    @Published var status: MusicStatus = .idle
    
    init() {}
    
    func play(_ song: Song) async {
        if status == .playing || status == .paused {
            aMusicPlayer.stop()
        }
        
        do {
            aMusicPlayer.queue = [song]
            status = .playing
            
            try await aMusicPlayer.play()
        } catch {
            status = .idle
            print("Error playing the song: \(error)")
        }
    }
    
    func pause() {
        guard status == .playing else { return }
        
        status = .paused
        aMusicPlayer.pause()
    }
    
    func stop() {
        guard status != .stopped else { return }
        
        status = .stopped
        aMusicPlayer.stop()
    }
}
