import Combine
import Foundation
import MusicKit
import SwiftUI

enum MusicStatus {
    case playing, paused, stopped, idle
}

let padding = 5

class MusicPlayer: ObservableObject {
    @EnvironmentObject private var musicManager: TrackStarManager

    var aMusicPlayer: ApplicationMusicPlayer = .shared
    @Published var status: MusicStatus = .idle
    @Published var timeElapsed: Int = 0
    private var isTimerRunning: Bool = false
    private var timer: Timer? = nil
    private var cancellable: AnyCancellable?
    
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
        pauseTimer()
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
        cleanTimer()
    }
    
    func setPlaybackTime(for song: Song, playbackTimeInterval: TimeInterval) {
        let songDuration = song.duration ?? 0
        
        aMusicPlayer.playbackTime = TimeInterval.random(in: TimeInterval(padding) ... songDuration - playbackTimeInterval)
    }
    
    func startTimer() {
        if isTimerRunning {
            return
        }
        
        isTimerRunning = true
        cancellable = Timer.publish(every: 1, on: .main, in: .common)
            .autoconnect()
            .sink { [weak self] _ in
                self?.updateTime()
            }
    }

    func pauseTimer() {
        isTimerRunning = false
        stopTimer()
    }

    private func updateTime() {
        if timeElapsed < 20 {
            timeElapsed += 1
        } else {
            cleanTimer()
        }
    }
    
    private func cleanTimer() {
        stopTimer()
        stop()
        timeElapsed = 0
    }

    private func stopTimer() {
        cancellable?.cancel()
        cancellable = nil
        isTimerRunning = false
    }
}
