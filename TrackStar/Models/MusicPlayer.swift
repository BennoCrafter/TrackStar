import Foundation
import MusicKit
import SwiftUI

enum MusicStatus {
    case playing, paused, stopped, idle
}

class MusicPlayer: ObservableObject {
    var aMusicPlayer: ApplicationMusicPlayer = .shared
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
    
    func play() async {
        guard status == .paused else { return }
        status = .playing
        try? await aMusicPlayer.play()
    }
    
    func stop() {
        guard status != .stopped else { return }
        
        status = .stopped
        aMusicPlayer.stop()
    }
}
