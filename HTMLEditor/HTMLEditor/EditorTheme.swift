import AppKit

/// Maps semantic ``TokenType`` values to editor colors using the currently
/// selected ``ThemePalette``. Colors are *dynamic*: each resolves differently
/// in light and dark mode, so syntax highlighting stays legible in either
/// appearance. Set ``current`` to switch themes; the highlighter then re-runs.
enum EditorTheme {

    /// The active palette. Defaults to the built-in "Default" theme; the
    /// settings store updates it when the user picks another theme.
    static var current: ThemePalette = ThemeLibrary.defaultTheme

    /// The editor font size, kept in sync with the settings. The highlighter
    /// uses ``font`` so re-highlighting preserves the chosen size.
    static var fontSize: CGFloat = 13
    static var font: NSFont { .monospacedSystemFont(ofSize: fontSize, weight: .regular) }

    /// The default text color for un-tokenized source.
    static var foreground: NSColor { color(current.foreground) }

    static func color(for type: TokenType) -> NSColor {
        switch type {
        case .doctype:      return .secondaryLabelColor
        case .comment:      return color(current.comment)
        case .tag:          return color(current.tag)
        case .attribute:    return color(current.attribute)
        case .string:       return color(current.string)

        case .cssSelector:  return color(current.tag)
        case .cssProperty:  return color(current.attribute)
        case .cssValue:     return color(current.value)
        case .cssComment:   return color(current.comment)

        case .jsKeyword:    return color(current.keyword)
        case .jsString:     return color(current.string)
        case .jsComment:    return color(current.comment)
        case .jsNumber:     return color(current.number)
        }
    }

    // MARK: - Hex → dynamic NSColor

    /// Build an `NSColor` that picks the palette's light or dark hex based on
    /// the appearance it is drawn with.
    private static func color(_ themeColor: ThemeColor) -> NSColor {
        let light = nsColor(fromHex: themeColor.light) ?? .labelColor
        let dark = nsColor(fromHex: themeColor.dark) ?? .labelColor
        return NSColor(name: nil) { appearance in
            appearance.bestMatch(from: [.aqua, .darkAqua]) == .darkAqua ? dark : light
        }
    }

    private static func nsColor(fromHex hex: String) -> NSColor? {
        guard let rgb = ThemePalette.rgb(fromHex: hex) else { return nil }
        return NSColor(srgbRed: CGFloat(rgb.red), green: CGFloat(rgb.green), blue: CGFloat(rgb.blue), alpha: 1)
    }
}
