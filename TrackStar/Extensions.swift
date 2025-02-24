import SwiftUI

extension Color {
    func toHex() -> String {
        let components = UIColor(self).cgColor.components ?? [0, 0, 0, 0]
        let r = components[0]
        let g = components[1]
        let b = components[2]
        return String(
            format: "#%02lX%02lX%02lX", lroundf(Float(r * 255)), lroundf(Float(g * 255)),
            lroundf(Float(b * 255)))
    }

    static func fromHex(_ hex: String) -> Color {
        var hexSanitized = hex.trimmingCharacters(in: .whitespacesAndNewlines)
        hexSanitized = hexSanitized.replacingOccurrences(of: "#", with: "")
        var rgb: UInt64 = 0
        Scanner(string: hexSanitized).scanHexInt64(&rgb)

        let red = Double((rgb >> 16) & 0xFF) / 255.0
        let green = Double((rgb >> 8) & 0xFF) / 255.0
        let blue = Double(rgb & 0xFF) / 255.0

        return Color(red: red, green: green, blue: blue)
    }

    static func getContrastColor(for color: Color) -> Color {
        let components = color.cgColor?.components ?? [0, 0, 0, 1]
        let r = components[0]
        let g = components[1]
        let b = components[2]

        let luminance = 0.2126 * r + 0.7152 * g + 0.0722 * b

        return luminance < 0.5 ? .white : .black
    }
}
