import CoreImage.CIFilterBuiltins
import SQLiteData
import SwiftUI

/// Makes `cards.pdf` for datasets that don't come from the repo (Apple Music, imported files),
/// with the same sheet layout as backend/cards.py: A4, 3 × 4 cards of 6.5 cm, each sheet a page
/// of QR fronts and a page of mirrored backs (print double-sided, flip on long edge).
@MainActor
enum CardPrinter {
    private static let cm: CGFloat = 72 / 2.54
    private static let page = CGSize(width: 595.28, height: 841.89)
    private static let card = 6.5 * cm
    private static let cols = 3, rows = 4
    private static var margin: CGSize {
        CGSize(width: (page.width - CGFloat(cols) * card) / 2, height: (page.height - CGFloat(rows) * card) / 2)
    }

    static func write(datasetID: String, title: String) throws -> URL {
        @Dependency(\.defaultDatabase) var database
        let tracks = try database.read { try Track.where { $0.datasetID.eq(datasetID) }.order(by: \.number).fetchAll($0) }
        let file = Library.cardsFile(datasetID)
        try FileManager.default.createDirectory(at: file.deletingLastPathComponent(), withIntermediateDirectories: true)

        var mediaBox = CGRect(origin: .zero, size: page)
        let info = [kCGPDFContextTitle: "\(title) – TrackStar cards", kCGPDFContextCreator: "TrackStar"] as CFDictionary
        guard let context = CGContext(file as CFURL, mediaBox: &mediaBox, info) else {
            throw CocoaError(.fileWriteUnknown)
        }
        let perPage = cols * rows
        for start in stride(from: 0, to: tracks.count, by: perPage) {
            let sheet = Array(tracks[start ..< min(start + perPage, tracks.count)])
            for backs in [false, true] {
                // `render` draws SwiftUI as vectors, so text stays sharp in print.
                ImageRenderer(content: Sheet(tracks: sheet, backs: backs)).render { _, draw in
                    context.beginPDFPage(nil)
                    draw(context)
                    context.endPDFPage()
                }
            }
        }
        context.closePDF()
        return file
    }

    private struct Sheet: View {
        let tracks: [Track]
        let backs: Bool

        var body: some View {
            ZStack(alignment: .topLeading) {
                Color.white
                ForEach(Array(tracks.enumerated()), id: \.offset) { index, track in
                    // Backs are flipped on the long edge when printed duplex.
                    let col = backs ? cols - 1 - index % cols : index % cols
                    Group {
                        if backs { Back(track: track) } else { Front(track: track) }
                    }
                    .frame(width: card, height: card)
                    .clipped()
                    .offset(x: margin.width + CGFloat(col) * card, y: margin.height + CGFloat(index / cols) * card)
                }
                marks
            }
            .frame(width: page.width, height: page.height)
            .environment(\.colorScheme, .light)
        }

        /// Cut marks in the margins, plus the grid behind the fronts.
        private var marks: some View {
            Path { path in
                for i in 0 ... cols {
                    let x = margin.width + CGFloat(i) * card
                    path.addLines([CGPoint(x: x, y: 0.3 * cm), CGPoint(x: x, y: margin.height - 0.15 * cm)])
                    path.addLines([CGPoint(x: x, y: page.height - margin.height + 0.15 * cm), CGPoint(x: x, y: page.height - 0.3 * cm)])
                }
                for i in 0 ... rows {
                    let y = margin.height + CGFloat(i) * card
                    path.addLines([CGPoint(x: 0.15 * cm, y: y), CGPoint(x: margin.width - 0.15 * cm, y: y)])
                    path.addLines([CGPoint(x: page.width - margin.width + 0.15 * cm, y: y), CGPoint(x: page.width - 0.15 * cm, y: y)])
                }
                if !backs {
                    for i in 0 ... cols {
                        let x = margin.width + CGFloat(i) * card
                        path.addLines([CGPoint(x: x, y: margin.height), CGPoint(x: x, y: page.height - margin.height)])
                    }
                    for i in 0 ... rows {
                        let y = margin.height + CGFloat(i) * card
                        path.addLines([CGPoint(x: margin.width, y: y), CGPoint(x: page.width - margin.width, y: y)])
                    }
                }
            }
            .stroke(Color(hex: 0x8A8799), lineWidth: 0.4)
        }
    }

    private struct Front: View {
        let track: Track

        var body: some View {
            ZStack(alignment: .bottomTrailing) {
                RoundedRectangle(cornerRadius: 0.35 * cm)
                    .stroke(Color(hex: 0xD9D7E0), lineWidth: 0.6)
                    .padding(0.25 * cm)
                QRCode(modules: modules("trackstar://\(track.datasetID)/?id=\(track.number)"))
                    .fill(Color(hex: 0x1F1B2E))
                    .frame(width: 4.2 * cm, height: 4.2 * cm)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                Text("#\(track.number)")
                    .font(.system(size: 5.5))
                    .foregroundStyle(Color(hex: 0x8A8799))
                    .padding(0.45 * cm)
            }
        }

        /// The dark modules of the code, top row first. Drawn as squares, not as an image:
        /// PDF viewers smooth a small bitmap into a blur no camera can read.
        private func modules(_ text: String) -> [[Bool]] {
            let filter = CIFilter.qrCodeGenerator()
            filter.message = Data(text.utf8)
            filter.correctionLevel = "M"
            guard let output = filter.outputImage,
                  let image = CIContext().createCGImage(output, from: output.extent),
                  let context = CGContext(
                      data: nil, width: image.width, height: image.height, bitsPerComponent: 8,
                      bytesPerRow: image.width, space: CGColorSpaceCreateDeviceGray(), bitmapInfo: CGImageAlphaInfo.none.rawValue),
                  let _ = Optional(context.draw(image, in: CGRect(x: 0, y: 0, width: image.width, height: image.height))),
                  let pixels = context.data?.assumingMemoryBound(to: UInt8.self)
            else { return [] }
            return (0 ..< image.height).map { y in
                (0 ..< image.width).map { x in pixels[y * image.width + x] < 128 }
            }
        }
    }

    private struct QRCode: Shape {
        let modules: [[Bool]]

        func path(in rect: CGRect) -> Path {
            Path { path in
                let size = rect.width / CGFloat(max(modules.count, 1))
                for (y, row) in modules.enumerated() {
                    for (x, isDark) in row.enumerated() where isDark {
                        path.addRect(CGRect(x: rect.minX + CGFloat(x) * size, y: rect.minY + CGFloat(y) * size, width: size, height: size))
                    }
                }
            }
        }
    }

    private struct Back: View {
        let track: Track

        var body: some View {
            VStack(spacing: 0) {
                Text(track.artist)
                    .font(.system(size: 12, weight: .bold))
                    .lineLimit(3)
                    .minimumScaleFactor(0.6)
                    .frame(height: 0.4 * card)
                if let year = track.year {
                    Text(String(year))
                        .font(.system(size: 46, weight: .bold))
                    Text(track.title)
                        .font(.system(size: 11).italic())
                        .lineLimit(3)
                        .minimumScaleFactor(0.6)
                        .frame(maxHeight: .infinity)
                } else {
                    // No year to show: the title takes its place in the middle.
                    Text(track.title)
                        .font(.system(size: 18, weight: .bold))
                        .lineLimit(3)
                        .minimumScaleFactor(0.5)
                        .frame(maxHeight: .infinity, alignment: .top)
                }
                if let album = track.album, album != track.title {
                    Text(album)
                        .font(.system(size: 6.5))
                        .opacity(0.7)
                        .lineLimit(1)
                }
            }
            .multilineTextAlignment(.center)
            .foregroundStyle(.white)
            .padding(0.5 * cm)
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .background(PeriodGradient.gradient(for: track.year))
        }
    }
}
