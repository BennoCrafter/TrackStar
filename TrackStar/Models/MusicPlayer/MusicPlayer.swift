import Combine
import Foundation
import MusicKit
import SwiftUI

enum MusicStatus {
    case playing, paused, stopped, idle
}

class MusicPlayerBase: ObservableObject {
    @Published var status: MusicStatus = .idle
    @Published var timeElapsed: Int = 0

    private var isTimerRunning: Bool = false
    private var cancellable: AnyCancellable?

    let timeIntervalPadding = TimeInterval(5)

    func play(_ song: Song) async {
        status = .playing
    }

    func play(song: Song, at playbackTime: TimeInterval) async {
        status = .playing
    }

    func play() async {
        status = .playing
    }

    func pause() {
        guard status == .playing else { return }
        status = .paused
    }

    func stop() {
        guard status != .stopped else { return }
        status = .stopped
    }

    func startTimer() {
        guard !isTimerRunning else { return }

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
