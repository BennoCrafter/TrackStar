import SwiftUI

/// The song plays, the card stays hidden: a countdown ring, play/pause and replay.
struct ListeningView: View {
    @Environment(GameModel.self) private var game

    private var progress: Double {
        min(game.elapsed / game.duration, 1)
    }

    var body: some View {
        VStack(spacing: 40) {
            ZStack {
                Circle()
                    .stroke(.white.opacity(0.12), lineWidth: 14)
                Circle()
                    .trim(from: 0, to: progress)
                    .stroke(.white, style: StrokeStyle(lineWidth: 14, lineCap: .round))
                    .rotationEffect(.degrees(-90))
                    .animation(.linear(duration: 0.2), value: progress)

                VStack(spacing: 8) {
                    Image(systemName: "waveform")
                        .font(.system(size: 44, weight: .semibold))
                        .symbolEffect(.variableColor.iterative.dimInactiveLayers, isActive: game.isPlaying)
                    Text(Duration.seconds(max(0, game.duration - game.elapsed)), format: .time(pattern: .minuteSecond))
                        .font(.title.monospacedDigit().weight(.semibold))
                        .contentTransition(.numericText(countsDown: true))
                }
            }
            .frame(width: 220, height: 220)

            HStack(spacing: 32) {
                Button(action: game.replay) {
                    Image(systemName: "gobackward")
                        .font(.title2.weight(.semibold))
                        .frame(width: 60, height: 60)
                        .background(.white.opacity(0.15), in: Circle())
                }
                .accessibilityLabel("Replay")

                Button(action: game.togglePlayback) {
                    Image(systemName: game.isPlaying ? "pause.fill" : "play.fill")
                        .font(.largeTitle)
                        .contentTransition(.symbolEffect(.replace))
                        .frame(width: 84, height: 84)
                        .foregroundStyle(.black)
                        .background(.white, in: Circle())
                }
                .accessibilityLabel(game.isPlaying ? "Pause" : "Play")

                // Keeps the play button centered.
                Color.clear.frame(width: 60, height: 60)
            }
            .buttonStyle(.plain)
        }
        .foregroundStyle(.white)
        .sensoryFeedback(.impact, trigger: game.isPlaying)
    }
}
