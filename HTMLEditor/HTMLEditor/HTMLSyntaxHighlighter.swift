import AppKit

/// Applies syntax coloring to an `NSTextStorage`. The actual classification is
/// done by the pure, unit-tested ``SyntaxTokenizer`` (which understands HTML
/// plus embedded CSS and JavaScript); this type only maps the resulting tokens
/// onto text attributes using the dark/light-aware ``EditorTheme``.
enum HTMLSyntaxHighlighter {

    static func highlight(_ storage: NSTextStorage) {
        let str = storage.string
        let full = NSRange(location: 0, length: (str as NSString).length)

        storage.beginEditing()

        // Reset every character to the default appearance first.
        storage.addAttribute(.font, value: EditorTheme.font, range: full)
        storage.addAttribute(.foregroundColor, value: EditorTheme.foreground, range: full)

        // Then color each classified token. Tokens are non-overlapping, so the
        // order in which we apply them does not matter.
        for token in SyntaxTokenizer.tokenize(str) {
            storage.addAttribute(.foregroundColor,
                                 value: EditorTheme.color(for: token.type),
                                 range: token.range)
        }

        storage.endEditing()
    }
}
