import Foundation

/// A light/dark color pair stored as `#rrggbb` hex strings.
struct ThemeColor: Codable, Equatable {
    var light: String
    var dark: String
}

/// A named palette mapping syntax roles to colors. Foundation-only (hex
/// strings); the AppKit layer converts these to dynamic `NSColor`s.
struct ThemePalette: Codable, Equatable, Identifiable {
    var name: String
    var foreground: ThemeColor
    var tag: ThemeColor
    var attribute: ThemeColor
    var string: ThemeColor
    var comment: ThemeColor
    var keyword: ThemeColor
    var value: ThemeColor
    var number: ThemeColor

    var id: String { name }

    /// Parse a `#rrggbb` (or `#rgb`) string into 0–1 RGB components.
    static func rgb(fromHex hex: String) -> (red: Double, green: Double, blue: Double)? {
        var s = hex.trimmingCharacters(in: .whitespaces)
        if s.hasPrefix("#") { s.removeFirst() }
        if s.count == 3 { s = s.map { "\($0)\($0)" }.joined() } // #abc → #aabbcc
        guard s.count == 6, let value = Int(s, radix: 16) else { return nil }
        return (Double((value >> 16) & 0xFF) / 255.0,
                Double((value >> 8) & 0xFF) / 255.0,
                Double(value & 0xFF) / 255.0)
    }
}

/// Built-in themes plus lookup. The default reproduces the original palette.
enum ThemeLibrary {
    static let defaultName = "Default"

    static let all: [ThemePalette] = [defaultTheme, midnight, sepia]

    static func palette(named name: String) -> ThemePalette {
        all.first { $0.name == name } ?? defaultTheme
    }

    static let defaultTheme = ThemePalette(
        name: "Default",
        foreground: ThemeColor(light: "#1a1a1a", dark: "#e6e6e6"),
        tag:        ThemeColor(light: "#006bc7", dark: "#66bcff"),
        attribute:  ThemeColor(light: "#8c26bf", dark: "#d19eff"),
        string:     ThemeColor(light: "#c72e2e", dark: "#fa8c7d"),
        comment:    ThemeColor(light: "#618562", dark: "#8cb38c"),
        keyword:    ThemeColor(light: "#a83380", dark: "#f28ccc"),
        value:      ThemeColor(light: "#26738c", dark: "#73d1eb"),
        number:     ThemeColor(light: "#996600", dark: "#e6bd66"))

    static let midnight = ThemePalette(
        name: "Midnight",
        foreground: ThemeColor(light: "#1b1f24", dark: "#d6deeb"),
        tag:        ThemeColor(light: "#0a66c2", dark: "#7fdbca"),
        attribute:  ThemeColor(light: "#9b5de5", dark: "#c792ea"),
        string:     ThemeColor(light: "#b34a2f", dark: "#ecc48d"),
        comment:    ThemeColor(light: "#6a737d", dark: "#637777"),
        keyword:    ThemeColor(light: "#c2185b", dark: "#82aaff"),
        value:      ThemeColor(light: "#1b7f8c", dark: "#addb67"),
        number:     ThemeColor(light: "#8a6d00", dark: "#f78c6c"))

    static let sepia = ThemePalette(
        name: "Sepia",
        foreground: ThemeColor(light: "#43342a", dark: "#ece0d1"),
        tag:        ThemeColor(light: "#9c4221", dark: "#e0a458"),
        attribute:  ThemeColor(light: "#8a5a2b", dark: "#d8b384"),
        string:     ThemeColor(light: "#a8321f", dark: "#e8a07d"),
        comment:    ThemeColor(light: "#8f8265", dark: "#b3a68a"),
        keyword:    ThemeColor(light: "#7b3f00", dark: "#e0a458"),
        value:      ThemeColor(light: "#406652", dark: "#a3c9a8"),
        number:     ThemeColor(light: "#996515", dark: "#dcb67a"))
}
