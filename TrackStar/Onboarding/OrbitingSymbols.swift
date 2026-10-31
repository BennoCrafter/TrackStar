import SwiftUI

/// Music symbols slowly circling the hero, each bobbing a little on its own rhythm.
struct OrbitingSymbols: View {
    let radius: CGFloat
    var paused = false
    var period: Double = 28

    private let symbols = [
        "music.note", "headphones", "guitars.fill",
        "music.mic", "pianokeys", "hifispeaker.fill",
    ]

    var body: some View {
        TimelineView(.animation(minimumInterval: nil, paused: paused)) { context in
            let time = paused ? 0 : context.date.timeIntervalSinceReferenceDate
            let rotation = time / period * 2 * .pi

            ZStack {
                ForEach(Array(symbols.enumerated()), id: \.offset) { index, name in
                    let angle = rotation + Double(index) / Double(symbols.count) * 2 * .pi
                    let bob = sin(time * 1.4 + Double(index) * 1.3) * 5

                    Image(systemName: name)
                        .font(.system(size: 17, weight: .semibold))
                        .foregroundStyle(Color.accentColor)
                        .frame(width: 38, height: 38)
                        .background(Color(.secondarySystemGroupedBackground), in: Circle())
                        .shadow(color: .black.opacity(0.08), radius: 6, y: 3)
                        .offset(
                            x: cos(angle) * radius,
                            y: sin(angle) * radius * 0.85 + bob
                        )
                }
            }
        }
        .allowsHitTesting(false)
    }
}
