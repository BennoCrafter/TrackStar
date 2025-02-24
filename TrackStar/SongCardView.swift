import SwiftUI

struct SongCardView: View {
    @StateObject var viewModel: ViewModel = .shared // Singleton ViewModel instance
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            // Song Artwork
            if let artworkURL = viewModel.song?.artwork?.url(width: 200, height: 200) {
                AsyncImage(url: artworkURL) { image in
                    image
                        .resizable()
                        .aspectRatio(contentMode: .fill)
                        .frame(height: 200)
                        .cornerRadius(12)
                } placeholder: {
                    ProgressView() // Placeholder while loading
                }
            } else {
                RoundedRectangle(cornerRadius: 12)
                    .fill(Color.gray.opacity(0.3))
                    .frame(height: 200)
                    .overlay(
                        Image(systemName: "music.note")
                            .font(.largeTitle)
                            .foregroundColor(.white.opacity(0.7))
                    )
            }
            
            // Song Title
            Text(viewModel.song?.title ?? "Unknown Title")
                .font(.headline)
                .foregroundColor(.primary)
                .lineLimit(1)
            
            // Song Artist
            Text(viewModel.song?.artistName ?? "Unknown Artist")
                .font(.subheadline)
                .foregroundColor(.secondary)
                .lineLimit(1)
        }
        .background(Color.white)
        .cornerRadius(16)
        .shadow(color: Color.black.opacity(0.2), radius: 10, x: 0, y: 5)
    }
}
