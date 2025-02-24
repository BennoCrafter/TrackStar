import MusicKit
import SwiftUI

private let displayDateFormatter: DateFormatter = {
    let formatter = DateFormatter()
    formatter.locale = Locale.autoupdatingCurrent
    formatter.dateFormat = DateFormatter.dateFormat(fromTemplate: "ddMMyyyy", options: 0, locale: formatter.locale)
    return formatter
}()

struct SongCard: View {
    @EnvironmentObject private var musicManager: MusicManager

    var body: some View {
        SongCardView(title: musicManager.song?.title, artistName: musicManager.song?.artistName, artworkURL: musicManager.song?.artwork?.url(width: 200, height: 200), releaseDate: musicManager.song?.releaseDate, appleMusicURL: musicManager.song?.url)
    }
}

struct SongCardView: View {
    var title: String?
    var artistName: String?
    var artworkURL: URL?
    var releaseDate: Date?
    var appleMusicURL: URL?

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            if let artworkURL = artworkURL {
                AsyncImage(url: artworkURL) { image in
                    image
                        .resizable()
                        .aspectRatio(contentMode: .fill)
                        .frame(height: 200)
                        .cornerRadius(12)
                } placeholder: {
                    fallbackArtwork
                }
            } else {
                fallbackArtwork
            }

            HStack {
                Text(title ?? "Unknown Title")
                    .font(.headline)
                    .foregroundColor(.primary)
                    .lineLimit(1)

                Spacer()

                if let appleMusicURL = appleMusicURL {
                    Button(action: {
                        UIApplication.shared.open(appleMusicURL)
                    }) {
                        HStack(spacing: 5) {
                            Image(systemName: "applelogo")
                                .font(.footnote)
                            Text("Apple Music")
                                .font(.footnote)
                                .fontWeight(.medium)
                        }
                        .padding(.horizontal, 10)
                        .padding(.vertical, 6)
                        .background(Color.red)
                        .foregroundColor(.white)
                        .cornerRadius(20)
                    }
                }
            }
            if let releaseDate = releaseDate {
                Text(displayDateFormatter.string(from: releaseDate))
                    .font(.footnote)
                    .foregroundColor(.secondary)
                    .lineLimit(1)
                    .padding(.top, 8)
            }

            Text(artistName ?? "Unknown Artist")
                .font(.subheadline)
                .foregroundColor(.secondary)
                .lineLimit(1)
        }
        .padding()
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(Color(.secondarySystemBackground))
                .overlay(
                    RoundedRectangle(cornerRadius: 16)
                        .stroke(Color.gray.opacity(0.3), lineWidth: 1)
                )
        )
        .shadow(color: Color.black.opacity(0.2), radius: 10, x: 0, y: 5)
        .frame(maxWidth: .infinity)
    }

    private var fallbackArtwork: some View {
        RoundedRectangle(cornerRadius: 12)
            .fill(Color.gray.opacity(0.3))
            .frame(height: 200)
            .overlay(
                Image(systemName: "music.note")
                    .font(.largeTitle)
                    .foregroundColor(Color(.label).opacity(0.7))
            )
    }
}

#Preview {
    SongCardView(
        title: "Just in Time",
        artistName: "Good Morning",
        artworkURL: URL(string: "https://i.ytimg.com/vi/LBynShoj_yc/maxresdefault.jpg"),
        releaseDate: Date(timeIntervalSince1970: 1709161200),
        appleMusicURL: URL(string: "https://music.apple.com/us/album/example")
    )
}
