import AppKit

/// Maps semantic ``TokenType`` values to editor colors. Colors are *dynamic*:
/// they resolve differently in light and dark mode, so syntax highlighting
/// stays legible whichever appearance the user runs.
enum EditorTheme {

    /// The default text color for un-tokenized source.
    static var foreground: NSColor { .labelColor }

    static func color(for type: TokenType) -> NSColor {
        switch type {
        case .doctype:      return .secondaryLabelColor
        case .comment:      return comment
        case .tag:          return tag
        case .attribute:    return attribute
        case .string:       return string

        case .cssSelector:  return tag
        case .cssProperty:  return attribute
        case .cssValue:     return value
        case .cssComment:   return comment

        case .jsKeyword:    return keyword
        case .jsString:     return string
        case .jsComment:    return comment
        case .jsNumber:     return number
        }
    }

    // MARK: - Palette (light / dark pairs)

    private static let tag = dynamic(
        light: NSColor(srgbRed: 0.00, green: 0.42, blue: 0.78, alpha: 1),   // blue
        dark:  NSColor(srgbRed: 0.40, green: 0.74, blue: 1.00, alpha: 1))

    private static let attribute = dynamic(
        light: NSColor(srgbRed: 0.55, green: 0.15, blue: 0.75, alpha: 1),   // purple
        dark:  NSColor(srgbRed: 0.82, green: 0.62, blue: 1.00, alpha: 1))

    private static let string = dynamic(
        light: NSColor(srgbRed: 0.78, green: 0.18, blue: 0.18, alpha: 1),   // red
        dark:  NSColor(srgbRed: 0.98, green: 0.55, blue: 0.49, alpha: 1))

    private static let comment = dynamic(
        light: NSColor(srgbRed: 0.38, green: 0.52, blue: 0.38, alpha: 1),   // muted green
        dark:  NSColor(srgbRed: 0.55, green: 0.70, blue: 0.55, alpha: 1))

    private static let keyword = dynamic(
        light: NSColor(srgbRed: 0.66, green: 0.20, blue: 0.50, alpha: 1),   // magenta
        dark:  NSColor(srgbRed: 0.95, green: 0.55, blue: 0.80, alpha: 1))

    private static let value = dynamic(
        light: NSColor(srgbRed: 0.15, green: 0.45, blue: 0.55, alpha: 1),   // teal
        dark:  NSColor(srgbRed: 0.45, green: 0.82, blue: 0.92, alpha: 1))

    private static let number = dynamic(
        light: NSColor(srgbRed: 0.60, green: 0.40, blue: 0.00, alpha: 1),   // amber
        dark:  NSColor(srgbRed: 0.90, green: 0.74, blue: 0.40, alpha: 1))

    // MARK: - Dynamic color helper

    /// Builds an `NSColor` that picks `light` or `dark` based on the appearance
    /// it is drawn with.
    private static func dynamic(light: NSColor, dark: NSColor) -> NSColor {
        NSColor(name: nil) { appearance in
            let match = appearance.bestMatch(from: [.aqua, .darkAqua])
            return match == .darkAqua ? dark : light
        }
    }
}
