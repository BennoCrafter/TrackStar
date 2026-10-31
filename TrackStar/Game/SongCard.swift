import MusicKit
import SwiftUI

/// The back of a printed card: artist, year and title on the gradient of its 5-year period.
struct SongCard: View {
    let track: Track
    let song: Song?

    /// The card's year; Apple Music's date is often a remaster's.
    private var year: Int? {
        track.year ?? song?.releaseDate.map { Calendar.current.component(.year, from: $0) }
    }

    var body: some View {
        VStack(spacing: 12) {
            Text(track.artist)
                .font(.title3.weight(.semibold))
                .lineLimit(2)
                .minimumScaleFactor(0.7)

            Spacer(minLength: 0)

            if let year {
                Text(String(year))
                    .font(.system(size: 88, weight: .black, design: .rounded))
                    .minimumScaleFactor(0.5)
                    .contentTransition(.numericText())
            } else {
                Image(systemName: "questionmark")
                    .font(.system(size: 64, weight: .black))
            }

            Spacer(minLength: 0)

            VStack(spacing: 4) {
                Text(track.title)
                    .font(.title3.weight(.bold))
                    .lineLimit(3)
                    .minimumScaleFactor(0.6)
                if let album = track.album ?? song?.albumTitle, album != track.title {
                    Text(album)
                        .font(.footnote)
                        .opacity(0.75)
                        .lineLimit(1)
                }
            }
        }
        .multilineTextAlignment(.center)
        .foregroundStyle(.white)
        .padding(28)
        .frame(maxWidth: 360)
        .aspectRatio(1, contentMode: .fit)
        .background(PeriodGradient.gradient(for: year), in: RoundedRectangle(cornerRadius: 32, style: .continuous))
        .overlay(alignment: .topTrailing) {
            if let artwork = song?.artwork {
                ArtworkImage(artwork, width: 56)
                    .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
                    .shadow(radius: 6)
                    .padding(14)
            }
        }
        .shadow(color: PeriodGradient.colors(for: year).0.opacity(0.5), radius: 24, y: 12)
        .accessibilityElement(children: .combine)
    }
}

/// Dark, tinted with a card's period color; the accent color without a card.
struct TintedBackground: View {
    var year: Int?

    var body: some View {
        let (start, end) = PeriodGradient.colors(for: year)
        ZStack {
            Color.black
            RadialGradient(
                colors: [(year == nil ? Color.accentColor : start).opacity(0.45), .clear],
                center: .top, startRadius: 0, endRadius: 600
            )
            RadialGradient(
                colors: [(year == nil ? Color.accentColor : end).opacity(0.25), .clear],
                center: .bottomTrailing, startRadius: 0, endRadius: 500
            )
        }
        .ignoresSafeArea()
        .animation(.easeInOut(duration: 0.8), value: year)
    }
}

/// The period colors of the printed cards.
enum PeriodGradient {
    static func gradient(for year: Int?) -> LinearGradient {
        let (start, end) = colors(for: year)
        return LinearGradient(colors: [start, end], startPoint: .topLeading, endPoint: .bottomTrailing)
    }

    /// From card-design.json, so the app's cards match the printed ones.
    static func colors(for year: Int?) -> (Color, Color) {
        let design = CardDesign.shared
        let hex = design.periodColors(for: year).map(design.hex)
        return (Color(hex: hex[0]), Color(hex: hex[1]))
    }
}

extension Color {
    init(hex: UInt32) {
        self.init(red: Double(hex >> 16 & 0xFF) / 255, green: Double(hex >> 8 & 0xFF) / 255, blue: Double(hex & 0xFF) / 255)
    }
}

#Preview {
    SongCard(track: Track(id: 1, datasetID: "hitster", number: 1, title: "You Can Call Me Al", artist: "Paul Simon", year: 1986), song: nil)
        .padding()
}
