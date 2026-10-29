import SwiftUI

/// The end of a game: the trophy, the winner, the standings, and confetti all over.
struct WinnerView: View {
    let winner: PartyPlayer
    let players: [PartyPlayer]
    let finish: () -> Void

    @State private var appeared = false
    /// One trigger per burst spot, fired one after another.
    @State private var bursts = Array(repeating: 0, count: 7)
    /// Where the bursts go, as fractions of the screen.
    @State private var spots = (0 ..< 7).map { _ in CGPoint(x: .random(in: 0.1 ... 0.9), y: .random(in: 0.15 ... 0.6)) }

    private var standings: [PartyPlayer] {
        players.sorted { ($0.score, $0.timeline.count) > ($1.score, $1.timeline.count) }
    }

    var body: some View {
        GeometryReader { geometry in
            let unit = min(geometry.size.height, geometry.size.width * 0.7)
            ZStack {
                Color.black.opacity(0.75)
                RadialGradient(colors: [.yellow.opacity(0.45), .clear], center: .center, startRadius: 0, endRadius: unit)
                    .scaleEffect(appeared ? 1 : 0.2)

                HStack(spacing: unit * 0.12) {
                    VStack(spacing: unit * 0.04) {
                        Image(systemName: "trophy.fill")
                            .font(.system(size: unit * 0.3))
                            .foregroundStyle(LinearGradient(colors: [.yellow, .orange], startPoint: .top, endPoint: .bottom))
                            .shadow(color: .yellow.opacity(0.6), radius: 30)
                            .symbolEffect(.bounce.up, options: .repeat(.periodic(delay: 1.2)), isActive: appeared)
                            .scaleEffect(appeared ? 1 : 0.1)
                            .rotationEffect(.degrees(appeared ? 0 : -45))
                        Text("\(winner.name) wins!")
                            .font(.system(size: unit * 0.1, weight: .black, design: .rounded))
                            .lineLimit(1)
                            .minimumScaleFactor(0.5)
                        Text("\(winner.score) points · \(winner.timeline.count) cards in the timeline")
                            .font(unit > 450 ? .title3 : .subheadline)
                            .foregroundStyle(.secondary)
                    }
                    .offset(y: appeared ? 0 : unit * 0.3)

                    VStack(alignment: .leading, spacing: unit * 0.025) {
                        ForEach(Array(standings.enumerated()), id: \.element.id) { rank, player in
                            HStack(spacing: 12) {
                                Text(rank < 3 ? ["🥇", "🥈", "🥉"][rank] : "\(rank + 1).")
                                    .frame(width: unit * 0.08)
                                Text(player.name).lineLimit(1)
                                Spacer(minLength: 16)
                                Text("\(player.score)").monospacedDigit().fontWeight(.black)
                            }
                            .font(.system(size: unit * 0.05, weight: .semibold, design: .rounded))
                            .opacity(appeared ? 1 : 0)
                            .offset(x: appeared ? 0 : 60)
                            .animation(.spring(response: 0.5, dampingFraction: 0.8).delay(0.4 + Double(rank) * 0.1), value: appeared)
                        }
                        Button(action: finish) {
                            Label("Finish", systemImage: "flag.checkered")
                                .font(.title2.bold())
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 8)
                        }
                        .buttonStyle(.borderedProminent)
                        .buttonBorderShape(.capsule)
                        .tint(.white)
                        .foregroundStyle(.black)
                        .padding(.top, unit * 0.03)
                        .opacity(appeared ? 1 : 0)
                        .animation(.easeOut.delay(0.9), value: appeared)
                    }
                    .frame(maxWidth: unit * 0.75)
                }
                .padding(32)
                .foregroundStyle(.white)

                ForEach(spots.indices, id: \.self) { index in
                    ConfettiBurst(trigger: bursts[index])
                        .scaleEffect(unit / 300) // the bursts are made for a small spot
                        .position(x: spots[index].x * geometry.size.width, y: spots[index].y * geometry.size.height)
                }
            }
        }
        .ignoresSafeArea()
        .sensoryFeedback(.success, trigger: appeared)
        .task {
            withAnimation(.spring(response: 0.7, dampingFraction: 0.6)) { appeared = true }
            for round in 0 ..< 18 {
                bursts[round % bursts.count] += 1
                try? await Task.sleep(for: .milliseconds(280))
            }
        }
    }
}

#Preview {
    let track = Track(id: 1, datasetID: "hitster", number: 1, title: "You Can Call Me Al", artist: "Paul Simon", year: 1986)
    let players = [
        PartyPlayer(name: "Anna", score: 10, timeline: Array(repeating: track, count: 11)),
        PartyPlayer(name: "Ben", score: 7, timeline: [track]),
        PartyPlayer(name: "Clara", score: 4, timeline: [track]),
    ]
    WinnerView(winner: players[0], players: players) {}
}
