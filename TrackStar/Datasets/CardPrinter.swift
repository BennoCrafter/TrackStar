import CoreText
import SQLiteData
import SwiftUI

/// `card-design.json`: the one source of truth for `cards.pdf`. The app renders it here for datasets that don't come
/// from the repo (Apple Music, imported files), backend/cards.py for the repo's datasets; both make the same PDF.
/// Format and rendering rules: backend/README.md, "Card design format". Change both renderers together.
struct CardDesign: Decodable, Sendable {
    struct Periods: Decodable, Sendable {
        let step: Int
        let none: [String]
        let colors: [String: [String]]
    }

    struct Sheet: Decodable, Sendable {
        struct Lines: Decodable, Sendable {
            let color: String
            let lineWidth: CGFloat
        }

        struct CutMarks: Decodable, Sendable {
            let color: String
            let lineWidth: CGFloat
            let edge: [CGFloat]
            let gap: CGFloat
        }

        let page: [CGFloat]
        let card: CGFloat
        let cols, rows: Int
        let grid: Lines
        let cutMarks: CutMarks
    }

    /// One drawing; which one depends on the key that is set (`rect`, `gradient`, `rings`, `qr`, `text`).
    struct Element: Decodable, Sendable {
        var `if`: [String]?
        var rect: [CGFloat]?, radius: CGFloat?, stroke: String?, lineWidth: CGFloat?
        var gradient: String?, from: [CGFloat]?, to: [CGFloat]?
        var rings: [CGFloat]?, step: CGFloat?, count: Int?, opacity: CGFloat?
        var qr: String?, color: String?
        var text: String?, font: String?, size: CGFloat?, minSize: CGFloat?, maxLines: Int?, box: [CGFloat]?, align: String?
    }

    let title: String
    let fonts: [String: String]
    let colors: [String: String]
    let periods: Periods
    let sheet: Sheet
    let front: [Element]
    let back: [Element]

    static let shared: CardDesign = {
        let url = Bundle.main.url(forResource: "card-design", withExtension: "json")!
        return try! JSONDecoder().decode(CardDesign.self, from: Data(contentsOf: url))
    }()

    /// Start and end hex color of the gradient for a year's 5-year period.
    func periodColors(for year: Int?) -> [String] {
        guard let year else { return periods.none }
        let keys = periods.colors.keys.compactMap(Int.init).sorted()
        return periods.colors[String(min(max(year / periods.step * periods.step, keys.first!), keys.last!))]!
    }

    func hex(_ name: String) -> UInt32 {
        UInt32((colors[name] ?? name).dropFirst(), radix: 16)!
    }
}

enum CardPrinter {
    private static let mm: CGFloat = 72 / 25.4

    static func write(datasetID: String, title: String) throws -> URL {
        @Dependency(\.defaultDatabase) var database
        let tracks = try database.read { try Track.where { $0.datasetID.eq(datasetID) }.order(by: \.number).fetchAll($0) }
        let file = Library.cardsFile(datasetID)
        try FileManager.default.createDirectory(at: file.deletingLastPathComponent(), withIntermediateDirectories: true)
        try render(tracks, title: title, to: file)
        return file
    }

    static func render(_ tracks: [Track], title: String, to file: URL) throws {
        let design = CardDesign.shared, sheet = design.sheet
        let page = CGSize(width: sheet.page[0] * mm, height: sheet.page[1] * mm), card = sheet.card * mm
        let margin = CGSize(width: (page.width - CGFloat(sheet.cols) * card) / 2, height: (page.height - CGFloat(sheet.rows) * card) / 2)
        var mediaBox = CGRect(origin: .zero, size: page)
        let info = [
            kCGPDFContextTitle: design.title.replacingOccurrences(of: "{label}", with: title),
            kCGPDFContextCreator: "TrackStar",
        ] as CFDictionary
        guard let context = CGContext(file as CFURL, mediaBox: &mediaBox, info) else {
            throw CocoaError(.fileWriteUnknown)
        }
        let renderer = try Renderer(design: design, context: context)
        let perPage = sheet.cols * sheet.rows
        for start in stride(from: 0, to: tracks.count, by: perPage) {
            for backs in [false, true] {
                context.beginPDFPage(nil)
                renderer.drawLines(page: page, margin: margin, fronts: !backs)
                for (i, track) in tracks[start ..< min(start + perPage, tracks.count)].enumerated() {
                    // Backs are flipped on the long edge when printed duplex.
                    let col = backs ? sheet.cols - 1 - i % sheet.cols : i % sheet.cols
                    let origin = CGPoint(x: margin.width + CGFloat(col) * card, y: page.height - margin.height - CGFloat(i / sheet.cols) * card)
                    renderer.drawCard(backs ? design.back : design.front, at: origin, track: track)
                }
                context.endPDFPage()
            }
        }
        context.closePDF()
    }

    /// Mirrors `_draw_card` / `_sheet_lines` in backend/cards.py. PDF space: pt, y up.
    private struct Renderer {
        let design: CardDesign
        let context: CGContext
        let fonts: [String: CGFont]

        init(design: CardDesign, context: CGContext) throws {
            self.design = design
            self.context = context
            fonts = try design.fonts.mapValues { file in
                guard let url = Bundle.main.url(forResource: file, withExtension: nil),
                      let provider = CGDataProvider(url: url as CFURL), let font = CGFont(provider)
                else { throw CocoaError(.fileReadNoSuchFile) }
                return font
            }
        }

        private func color(_ name: String, alpha: CGFloat = 1) -> CGColor {
            rgb(design.hex(name), alpha: alpha)
        }

        private func rgb(_ hex: UInt32, alpha: CGFloat = 1) -> CGColor {
            let c = [hex >> 16 & 0xFF, hex >> 8 & 0xFF, hex & 0xFF].map { CGFloat($0) / 255 }
            return CGColor(colorSpace: CGColorSpaceCreateDeviceRGB(), components: c + [alpha])!
        }

        func drawLines(page: CGSize, margin: CGSize, fronts: Bool) {
            let sheet = design.sheet, card = sheet.card * mm
            let xs = (0 ... sheet.cols).map { margin.width + CGFloat($0) * card }
            let ys = (0 ... sheet.rows).map { margin.height + CGFloat($0) * card }
            context.saveGState()
            if fronts {
                context.setStrokeColor(color(sheet.grid.color))
                context.setLineWidth(sheet.grid.lineWidth)
                context.strokeLineSegments(between: xs.flatMap { [CGPoint(x: $0, y: ys.first!), CGPoint(x: $0, y: ys.last!)] }
                    + ys.flatMap { [CGPoint(x: xs.first!, y: $0), CGPoint(x: xs.last!, y: $0)] })
            }
            let marks = sheet.cutMarks
            let ex = marks.edge[0] * mm, ey = marks.edge[1] * mm, gap = marks.gap * mm
            var points: [CGPoint] = []
            for x in xs {
                points += [CGPoint(x: x, y: ey), CGPoint(x: x, y: margin.height - gap)]
                points += [CGPoint(x: x, y: page.height - margin.height + gap), CGPoint(x: x, y: page.height - ey)]
            }
            for y in ys {
                points += [CGPoint(x: ex, y: y), CGPoint(x: margin.width - gap, y: y)]
                points += [CGPoint(x: page.width - margin.width + gap, y: y), CGPoint(x: page.width - ex, y: y)]
            }
            context.setStrokeColor(color(marks.color))
            context.setLineWidth(marks.lineWidth)
            context.strokeLineSegments(between: points)
            context.restoreGState()
        }

        /// `origin`: the card's top-left corner. Element coordinates are mm from there, y down.
        func drawCard(_ elements: [CardDesign.Element], at origin: CGPoint, track: Track) {
            func p(_ x: CGFloat, _ y: CGFloat) -> CGPoint { CGPoint(x: origin.x + x * mm, y: origin.y - y * mm) }
            let fields = [
                "dataset": track.datasetID, "id": String(track.number), "title": track.title, "artist": track.artist,
                "year": track.year.map(String.init) ?? "", "album": track.album ?? "",
            ]
            func fill(_ template: String) -> String {
                template.replacing(#/\{(\w+)\}/#) { fields[String($0.1)] ?? "" }
            }
            func holds(_ condition: String) -> Bool {
                let parts = condition.components(separatedBy: "!=").map { $0.trimmingCharacters(in: .whitespaces) }
                if parts.count == 2 { return fields[parts[0]] != fields[parts[1]] }
                if condition.hasPrefix("!") { return fields[String(condition.dropFirst())]!.isEmpty }
                return !fields[condition]!.isEmpty
            }

            let card = design.sheet.card * mm
            context.saveGState()
            context.clip(to: CGRect(x: origin.x, y: origin.y - card, width: card, height: card))
            for e in elements where (e.if ?? []).allSatisfy(holds) {
                context.saveGState()
                if let rect = e.rect, e.qr == nil {
                    let r = (e.radius ?? 0) * mm
                    let bounds = CGRect(x: origin.x + rect[0] * mm, y: origin.y - (rect[1] + rect[3]) * mm, width: rect[2] * mm, height: rect[3] * mm)
                    context.addPath(CGPath(roundedRect: bounds, cornerWidth: r, cornerHeight: r, transform: nil))
                    context.setStrokeColor(color(e.stroke!))
                    context.setLineWidth(e.lineWidth!)
                    context.strokePath()
                } else if e.gradient != nil, let from = e.from, let to = e.to {
                    let colors = design.periodColors(for: track.year).map { rgb(UInt32($0.dropFirst(), radix: 16)!) }
                    let gradient = CGGradient(colorsSpace: CGColorSpaceCreateDeviceRGB(), colors: colors as CFArray, locations: [0, 1])!
                    context.drawLinearGradient(gradient, start: p(from[0], from[1]), end: p(to[0], to[1]),
                                               options: [.drawsBeforeStartLocation, .drawsAfterEndLocation])
                } else if let center = e.rings {
                    context.setStrokeColor(color(e.stroke!, alpha: e.opacity ?? 1))
                    context.setLineWidth(e.lineWidth!)
                    for i in 0 ..< e.count! {
                        let r = (e.radius! + CGFloat(i) * e.step!) * mm
                        context.addEllipse(in: CGRect(origin: p(center[0], center[1]), size: .zero).insetBy(dx: -r, dy: -r))
                    }
                    context.strokePath()
                } else if let qr = e.qr, let rect = e.rect {
                    let modules = QRMatrix.modules(fill(qr))
                    let s = rect[2] * mm / CGFloat(modules.count), topLeft = p(rect[0], rect[1])
                    for (row, line) in modules.enumerated() {
                        for (col, dark) in line.enumerated() where dark {
                            context.addRect(CGRect(x: topLeft.x + CGFloat(col) * s, y: topLeft.y - CGFloat(row + 1) * s, width: s, height: s))
                        }
                    }
                    context.setFillColor(color(e.color!))
                    context.fillPath()
                } else if let text = e.text, let box = e.box {
                    drawText(fill(text), element: e, left: origin.x + box[0] * mm, centerY: origin.y - box[1] * mm, width: box[2] * mm)
                }
                context.restoreGState()
            }
            context.restoreGState()
        }

        private func drawText(_ text: String, element e: CardDesign.Element, left: CGFloat, centerY: CGFloat, width: CGFloat) {
            let cgFont = fonts[e.font!]!
            let (size, lines) = fit(clean(text), font: cgFont, size: e.size!, minSize: e.minSize ?? e.size!, width: width, maxLines: e.maxLines ?? 1)
            let font = CTFontCreateWithGraphicsFont(cgFont, size, nil, nil)
            let leading = size * 1.15
            let baseline = centerY + CGFloat(lines.count - 1) * leading / 2 - size * 0.35
            context.setFillColor(color(e.color!))
            context.setAlpha(e.opacity ?? 1)
            context.textMatrix = .identity
            for (i, line) in lines.enumerated() {
                let glyphs = Self.glyphs(line, font)
                var advances = [CGSize](repeating: .zero, count: glyphs.count)
                let lineWidth = CTFontGetAdvancesForGlyphs(font, .horizontal, glyphs, &advances, glyphs.count)
                // Glyph by glyph at their advances, like reportlab: no kerning, no ligatures.
                var x = switch e.align ?? "center" {
                case "left": left
                case "right": left + width - lineWidth
                default: left + (width - lineWidth) / 2
                }
                let y = baseline - CGFloat(i) * leading
                let positions = advances.map { advance in
                    defer { x += advance.width }
                    return CGPoint(x: x, y: y)
                }
                CTFontDrawGlyphs(font, glyphs, positions, glyphs.count, context)
            }
        }

        /// One glyph per Unicode scalar, glyph 0 if the font lacks it (as reportlab does).
        private static func glyphs(_ text: String, _ font: CTFont) -> [CGGlyph] {
            text.unicodeScalars.map { scalar in
                var units = Array(String(scalar).utf16)
                var glyphs = [CGGlyph](repeating: 0, count: units.count)
                CTFontGetGlyphsForCharacters(font, &units, &glyphs, units.count)
                return glyphs[0]
            }
        }

        private func clean(_ text: String) -> String {
            let scalars = text.unicodeScalars.compactMap { scalar -> Unicode.Scalar? in
                if "\t\n\r".unicodeScalars.contains(scalar) { return " " }
                return scalar.properties.generalCategory == .format ? nil : scalar
            }
            return String(String.UnicodeScalarView(scalars)).trimmingCharacters(in: CharacterSet(charactersIn: " "))
        }

        /// Shrinks by 0.5 pt until the text wraps into `maxLines`; ellipsizes if even `minSize` is too big.
        private func fit(_ text: String, font cgFont: CGFont, size: CGFloat, minSize: CGFloat, width: CGFloat, maxLines: Int) -> (CGFloat, [String]) {
            var size = size
            var lines: [String]
            func measure(_ s: String) -> CGFloat {
                let font = CTFontCreateWithGraphicsFont(cgFont, size, nil, nil)
                let glyphs = Self.glyphs(s, font)
                return CTFontGetAdvancesForGlyphs(font, .horizontal, glyphs, nil, glyphs.count)
            }
            while true {
                lines = []
                for word in text.unicodeScalars.split(separator: " ").map({ String(String.UnicodeScalarView($0)) }) {
                    if let last = lines.last, measure(last + " " + word) <= width {
                        lines[lines.count - 1] = last + " " + word
                    } else {
                        lines.append(word)
                    }
                }
                if lines.count <= maxLines || size - 0.5 < minSize { break }
                size -= 0.5
            }
            if lines.count > maxLines {
                lines = Array(lines.prefix(maxLines))
                var last = lines[maxLines - 1].unicodeScalars
                while !last.isEmpty, measure(String(last) + "…") > width { last.removeLast() }
                while last.last == " " { last.removeLast() }
                lines[maxLines - 1] = String(last) + "…"
            }
            return (size, lines)
        }
    }
}
