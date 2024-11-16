import Foundation
import MusicKit

enum MusicStatus {
    case playing, paused, stopped, idle
}

class MusicPlayer: ObservableObject {
    private var musicPlayer: ApplicationMusicPlayer = .shared
    @Published var status: MusicStatus = .idle
    
    init() {}
    
    func play(_ song: Song) async {
        // Only stop if it's playing or paused (avoid unnecessary stop calls)
        if status == .playing || status == .paused {
            musicPlayer.stop()
        }
        
        do {
            // Set the queue to the new song
            musicPlayer.queue = [song]
            status = .playing
            
            // Play the song
            try await musicPlayer.play()
        } catch {
            status = .idle
            print("Error playing the song: \(error)")
        }
    }
    
    func pause() {
        guard status == .playing else { return }
        
        status = .paused
        musicPlayer.pause()
    }
    
    func stop() {
        guard status != .stopped else { return }
        
        status = .stopped
        musicPlayer.stop()
    }
}
