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

/// Same colors as `PERIOD_COLORS` in backend/cards.py, so the app matches the printed cards.
enum PeriodGradient {
    static func gradient(for year: Int?) -> LinearGradient {
        let (start, end) = colors(for: year)
        return LinearGradient(colors: [start, end], startPoint: .topLeading, endPoint: .bottomTrailing)
    }

    static func colors(for year: Int?) -> (Color, Color) {
        guard let year else { return (Color(hex: 0x334155), Color(hex: 0x64748B)) }
        return switch min(max(year / 5 * 5, 1950), 2025) {
        case 1950: (Color(hex: 0x3B0764), Color(hex: 0x7E22CE))
        case 1955: (Color(hex: 0x1E3A8A), Color(hex: 0x4338CA))
        case 1960: (Color(hex: 0x9F1239), Color(hex: 0xEA580C))
        case 1965: (Color(hex: 0x0E7490), Color(hex: 0x0D9488))
        case 1970: (Color(hex: 0x9A3412), Color(hex: 0xCA8A04))
        case 1975: (Color(hex: 0x4D7C0F), Color(hex: 0x15803D))
        case 1980: (Color(hex: 0xBE185D), Color(hex: 0x6D28D9))
        case 1985: (Color(hex: 0x0369A1), Color(hex: 0x7C3AED))
        case 1990: (Color(hex: 0x0F766E), Color(hex: 0x0369A1))
        case 1995: (Color(hex: 0xA21CAF), Color(hex: 0xDB2777))
        case 2000: (Color(hex: 0x1E40AF), Color(hex: 0x7C3AED))
        case 2005: (Color(hex: 0xB45309), Color(hex: 0xDC2626))
        case 2010: (Color(hex: 0x065F46), Color(hex: 0x4D7C0F))
        case 2015: (Color(hex: 0x4338CA), Color(hex: 0x0891B2))
        case 2020: (Color(hex: 0xB91C1C), Color(hex: 0xC026D3))
        default: (Color(hex: 0x7C2D12), Color(hex: 0xBE123C))
        }
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
