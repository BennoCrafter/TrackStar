import SwiftUI

struct PlayMenu: View {
    @EnvironmentObject private var trackStarManager: TrackStarManager

    var body: some View {
        NavigationStack {
            Spacer()

            Button(action: {
                if trackStarManager.musicPlayer.status == .playing {
                    trackStarManager.musicPlayer.pause()
                } else {}
            }) {
                Image(systemName: trackStarManager.musicPlayer.status == .playing ? "pause.circle.fill" : "play.circle.fill")
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
