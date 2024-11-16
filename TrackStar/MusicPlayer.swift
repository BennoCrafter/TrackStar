import Foundation
import MusicKit

class MusicPlayer: ObservableObject {
    private let musicPlayer = ApplicationMusicPlayer.shared

    func play(_ song: Song) async {
        do {
            musicPlayer.queue = [song]
            try await musicPlayer.play()
        } catch {
            print("Error playing the song: \(error.localizedDescription)")
        }
    }

    func pause() {
        musicPlayer.pause()
    }
}
