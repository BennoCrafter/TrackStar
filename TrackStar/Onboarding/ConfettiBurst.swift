import SwiftUI

/// A one-shot burst: pieces spring outward from the center, then tumble down and fade.
struct ConfettiBurst: View {
    let trigger: Int

    @State private var pieces = (0..<40).map { _ in ConfettiPiece.random() }

    var body: some View {
        ZStack {
            ForEach(pieces) { piece in
                let total = 0.45 + piece.fallDuration

                RoundedRectangle(cornerRadius: piece.cornerRadius)
                    .fill(piece.color)
                    .frame(width: piece.size.width, height: piece.size.height)
                    .keyframeAnimator(initialValue: ConfettiFrame(), trigger: trigger) { content, frame in
                        content
                            .rotation3DEffect(.degrees(frame.rotation), axis: piece.axis)
                            .scaleEffect(frame.scale)
                            .offset(x: frame.x, y: frame.y)
                            .opacity(frame.opacity)
                    } keyframes: { _ in
                        KeyframeTrack(\.x) {
                            SpringKeyframe(piece.burst.width, duration: 0.45, spring: .snappy)
                            CubicKeyframe(piece.burst.width + piece.drift, duration: piece.fallDuration)
                        }
                        KeyframeTrack(\.y) {
                            SpringKeyframe(piece.burst.height, duration: 0.45, spring: .snappy)
                            CubicKeyframe(piece.burst.height + piece.fallDistance, duration: piece.fallDuration)
                        }
                        KeyframeTrack(\.rotation) {
                            CubicKeyframe(piece.spin, duration: total)
                        }
                        KeyframeTrack(\.scale) {
                            SpringKeyframe(1, duration: 0.3, spring: .bouncy)
                            LinearKeyframe(0.7, duration: total - 0.3)
                        }
                        KeyframeTrack(\.opacity) {
                            LinearKeyframe(1, duration: 0.05)
                            LinearKeyframe(1, duration: total * 0.6)
                            LinearKeyframe(0, duration: total * 0.4 - 0.05)
                        }
                    }
            }
        }
        .allowsHitTesting(false)
    }
}

/// Animated values for one confetti piece. Starts invisible so nothing shows before the trigger.
struct ConfettiFrame {
    var x: Double = 0
    var y: Double = 0
    var rotation: Double = 0
    var scale: Double = 0.2
    var opacity: Double = 0
}

struct ConfettiPiece: Identifiable {
    let id = UUID()
    let burst: CGSize
    let drift: Double
    let fallDistance: Double
    let fallDuration: Double
    let spin: Double
    let axis: (x: CGFloat, y: CGFloat, z: CGFloat)
    let color: Color
    let size: CGSize
    let cornerRadius: CGFloat

    private static let palette: [Color] = [.accentColor, .pink, .orange, .yellow, .mint, .purple, .cyan]

    static func random() -> ConfettiPiece {
        let angle = Double.random(in: 0..<2 * .pi)
        let distance = Double.random(in: 80...170)
        let isDot = Int.random(in: 0..<4) == 0
        let size = isDot
            ? CGSize(width: 7, height: 7)
            : CGSize(width: .random(in: 5...8), height: .random(in: 9...14))

        return ConfettiPiece(
            burst: CGSize(width: cos(angle) * distance, height: sin(angle) * distance * 0.8 - 40),
            drift: .random(in: -30...30),
            fallDistance: .random(in: 120...220),
            fallDuration: .random(in: 0.9...1.4),
            spin: .random(in: -540...540),
            axis: (x: .random(in: 0...1), y: .random(in: 0...1), z: 1),
            color: palette.randomElement() ?? .accentColor,
            size: size,
            cornerRadius: isDot ? 3.5 : 1.5)
    }
}
