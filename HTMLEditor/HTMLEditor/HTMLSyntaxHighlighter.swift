import AppKit

enum HTMLSyntaxHighlighter {

    // MARK: - Colors (adapt for dark/light mode via NSColor semantics)
    private static let tagColor     = NSColor(red: 0.00, green: 0.48, blue: 0.86, alpha: 1) // blue
    private static let attrColor    = NSColor(red: 0.55, green: 0.15, blue: 0.75, alpha: 1) // purple
    private static let stringColor  = NSColor(red: 0.78, green: 0.18, blue: 0.18, alpha: 1) // red
    private static let commentColor = NSColor(red: 0.38, green: 0.52, blue: 0.38, alpha: 1) // muted green
    private static let doctypeColor = NSColor.secondaryLabelColor

    static func highlight(_ storage: NSTextStorage) {
        let str = storage.string
        guard !str.isEmpty else { return }
        let full = NSRange(str.startIndex..., in: str)

        storage.beginEditing()

        // Reset to defaults
        storage.addAttribute(.foregroundColor, value: NSColor.labelColor, range: full)
        storage.addAttribute(.font,
            value: NSFont.monospacedSystemFont(ofSize: 13, weight: .regular),
            range: full)

        // Order matters: later rules override earlier ones for the same range.
        // Comments must come last so they win over tag/attr colors inside them.
        apply("<!DOCTYPE[^>]*>",   color: doctypeColor, to: storage, in: str, options: .caseInsensitive)
        apply("</?[a-zA-Z][a-zA-Z0-9-]*", color: tagColor,   to: storage, in: str)
        apply("/?>",               color: tagColor,    to: storage, in: str)
        apply("\\b[a-zA-Z-]+(?=\\s*=)", color: attrColor, to: storage, in: str)
        apply("\"[^\"\\n]*\"",    color: stringColor,  to: storage, in: str)
        apply("'[^'\\n]*'",       color: stringColor,  to: storage, in: str)
        apply("<!--[\\s\\S]*?-->", color: commentColor, to: storage, in: str)

        storage.endEditing()
    }

    private static func apply(
        _ pattern: String,
        color: NSColor,
        to storage: NSTextStorage,
        in str: String,
        options: NSRegularExpression.Options = []
    ) {
        guard let regex = try? NSRegularExpression(pattern: pattern, options: options) else { return }
        let full = NSRange(str.startIndex..., in: str)
        for match in regex.matches(in: str, range: full) {
            storage.addAttribute(.foregroundColor, value: color, range: match.range)
        }
    }
}
