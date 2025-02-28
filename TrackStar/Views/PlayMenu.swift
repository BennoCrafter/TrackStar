import SwiftUI

struct PlayMenu: View {
    @EnvironmentObject private var trackStarManager: TrackStarManager
    @State private var isPlaying: Bool = true

    var body: some View {
        NavigationStack {
            Spacer()

            Button(action: {
                Task {
                    await trackStarManager.togglePlayState()
                    isPlaying = trackStarManager.musicPlayer.status == .playing
                }
            }) {
                Image(systemName: isPlaying ? "pause.circle.fill" : "play.circle.fill")
                    .resizable()
                    .frame(width: 100, height: 100)
                    .foregroundStyle(.blue)
            }

            Spacer()
        }
    }
}

#Preview {
    PlayMenu()
        .environmentObject(TrackStarManager.shared)
}
