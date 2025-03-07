import Combine
import Foundation
import MusicKit
import SwiftUI

let timeIntervalPadding = TimeInterval(5)

class AppleMusicPlayer: MusicPlayerBase {
    var aMusicPlayer: ApplicationMusicPlayer = .shared

    override func play(_ song: Song) async {
        await super.play(song)

        do {
            aMusicPlayer.queue = [song]
            try await aMusicPlayer.play()
        } catch {
            status = .idle
            print("Error playing the song: \(error)")
        }
    }

    override func play(song: Song, at playbackTime: TimeInterval) async {
        await super.play(song: song, at: playbackTime)

        await play(song)
        aMusicPlayer.playbackTime = playbackTime
    }

    override func play() async {
        await super.play()

        do {
            try await aMusicPlayer.play()
        } catch {
            print("Error playing song: \(error)")
        }
    }

    override func pause() {
        super.pause()
        aMusicPlayer.pause()
    }

    override func stop() {
        super.stop()
        aMusicPlayer.stop()
    }
}
