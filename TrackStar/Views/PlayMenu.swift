import SwiftUI

struct PlayMenu: View {
    @EnvironmentObject private var trackStarManager: TrackStarManager
    
    var body: some View {
        VStack {
            Button(action: {
                Task {
                    await trackStarManager.togglePlayState()
                }
            }) {
                ZStack {
                    if trackStarManager.musicPlayer.status == .idle {
                        ProgressView()
                            .progressViewStyle(CircularProgressViewStyle())
                            .scaleEffect(2)
                    } else {
                        Image(systemName: trackStarManager.musicPlayer.status == .playing ? "pause.circle.fill" :
                            trackStarManager.musicPlayer.status == .paused ? "play.circle.fill" : "arrow.clockwise")
                            .resizable()
                            .scaledToFit()
                            .foregroundStyle(.blue)
                    }
                }
            }
            .frame(width: 100, height: 100)
            
            ProgressView(value: Double(trackStarManager.musicPlayer.timeElapsed), total: Double(trackStarManager.appConfig.playbackTimeInterval))
                .progressViewStyle(LinearProgressViewStyle())
                .padding()
                
            Text(formatTime(TimeInterval(trackStarManager.musicPlayer.timeElapsed)))
                .font(.headline)
                .padding(.top, 5)
            
            if let songID = trackStarManager.scannedCodeMetadata?.id {
                Text("Song ID: \(songID)")
                    .font(.headline)
                    .padding(.top, 10)
            } else {
                Text("Unknown song ID")
                    .font(.subheadline)
                    .foregroundColor(.gray)
            }
        }
        .padding()
    }
    
    private func formatTime(_ time: TimeInterval) -> String {
        let minutes = Int(time) / 60
        let seconds = Int(time) % 60
        return String(format: "%02d:%02d", minutes, seconds)
    }
}

#Preview {
    PlayMenu()
        .environmentObject(TrackStarManager.shared)
}
