import Foundation

/// Options controlling a find/replace operation.
struct FindOptions: Equatable {
    var caseSensitive = false
    var wholeWord = false
    var useRegex = false

    init(caseSensitive: Bool = false, wholeWord: Bool = false, useRegex: Bool = false) {
        self.caseSensitive = caseSensitive
        self.wholeWord = wholeWord
        self.useRegex = useRegex
    }
}

/// Pure find/replace logic shared by the find bar UI. Returns UTF-16 `NSRange`
/// values so results can be applied directly to an `NSTextView`.
enum FindEngine {

    /// All non-overlapping matches of `query` in `text`. Empty if the query is
    /// empty or the (regex) pattern is invalid.
    static func matches(in text: String, query: String, options: FindOptions = FindOptions()) -> [NSRange] {
        guard !query.isEmpty, let regex = makeRegex(query, options) else { return [] }
        let full = NSRange(location: 0, length: (text as NSString).length)
        return regex.matches(in: text, range: full)
            .map(\.range)
            .filter { $0.length > 0 }
    }

    /// Replace every match of `query` with `replacement`. In literal mode the
    /// replacement is inserted verbatim; in regex mode `$1`-style templates are
    /// honored. Returns the new text and the number of replacements made.
    static func replaceAll(in text: String,
                           query: String,
                           replacement: String,
                           options: FindOptions = FindOptions()) -> (text: String, count: Int) {
        guard !query.isEmpty, let regex = makeRegex(query, options) else { return (text, 0) }
        let mutable = NSMutableString(string: text)
        let full = NSRange(location: 0, length: mutable.length)
        let template = options.useRegex
            ? replacement
            : NSRegularExpression.escapedTemplate(for: replacement)
        let count = regex.replaceMatches(in: mutable, range: full, withTemplate: template)
        return (mutable as String, count)
    }

    /// Index of the match to select when stepping through results, wrapping
    /// around at either end. Returns `nil` when there are no matches.
    ///
    /// - Parameter current: index of the currently selected match, or `nil`.
    static func step(from current: Int?, total: Int, forward: Bool) -> Int? {
        guard total > 0 else { return nil }
        guard let current else { return forward ? 0 : total - 1 }
        if forward { return (current + 1) % total }
        return (current - 1 + total) % total
    }

    /// Index of the first match at or after `location`, used to resume a search
    /// from the current caret/selection. Falls back to the first match.
    static func firstMatchIndex(in ranges: [NSRange], atOrAfter location: Int) -> Int? {
        guard !ranges.isEmpty else { return nil }
        return ranges.firstIndex { $0.location >= location } ?? 0
    }

    // MARK: - Private

    private static func makeRegex(_ query: String, _ options: FindOptions) -> NSRegularExpression? {
        var pattern = options.useRegex ? query : NSRegularExpression.escapedPattern(for: query)
        if options.wholeWord {
            pattern = "\\b(?:\(pattern))\\b"
        }
        var regexOptions: NSRegularExpression.Options = []
        if !options.caseSensitive { regexOptions.insert(.caseInsensitive) }
        return try? NSRegularExpression(pattern: pattern, options: regexOptions)
    }
}
