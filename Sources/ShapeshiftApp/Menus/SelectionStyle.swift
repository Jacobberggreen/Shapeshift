import SwiftUI
import AppKit

/// Fill and label colour of the highlighted pie slice, from the Settings choice.
struct SelectionStyle: Equatable {
    var fill: Color
    var labelIsLight: Bool

    var label: Color { labelIsLight ? .white : .black }

    static func resolve(mode: SelectionColorMode, customHex: String, accent: NSColor = .controlAccentColor) -> SelectionStyle {
        let base = accent.usingColorSpace(.sRGB) ?? NSColor(srgbRed: 0.04, green: 0.52, blue: 1, alpha: 1)
        let color: NSColor
        switch mode {
        case .accent: color = base
        case .lighter: color = NSColor(srgbRed: 0.86, green: 0.86, blue: 0.88, alpha: 1)   // soft near-white, not pure white
        case .darker: color = NSColor(srgbRed: 0.20, green: 0.20, blue: 0.22, alpha: 1)    // soft near-black, not pure black
        case .custom: color = parseHex(customHex) ?? parseHex(SettingsStore.defaultSelectionHex)!
        }
        return SelectionStyle(fill: Color(nsColor: color), labelIsLight: luminance(of: color) < 0.6)
    }

    /// Relative luminance (sRGB weights) of a colour, 0 = black, 1 = white.
    static func luminance(of color: NSColor) -> Double {
        let c = color.usingColorSpace(.sRGB) ?? color
        return 0.2126 * Double(c.redComponent) + 0.7152 * Double(c.greenComponent) + 0.0722 * Double(c.blueComponent)
    }

    static func parseHex(_ text: String) -> NSColor? {
        var hex = text.trimmingCharacters(in: .whitespaces)
        if hex.hasPrefix("#") { hex.removeFirst() }
        guard hex.count == 6, let value = UInt32(hex, radix: 16) else { return nil }
        return NSColor(srgbRed: CGFloat((value >> 16) & 0xFF) / 255, green: CGFloat((value >> 8) & 0xFF) / 255,
                       blue: CGFloat(value & 0xFF) / 255, alpha: 1)
    }

    static func hex(of color: NSColor) -> String {
        let c = color.usingColorSpace(.sRGB) ?? color
        func byte(_ v: CGFloat) -> Int { Int((min(max(v, 0), 1) * 255).rounded()) }
        return String(format: "#%02X%02X%02X", byte(c.redComponent), byte(c.greenComponent), byte(c.blueComponent))
    }
}
