import Foundation

/// Pure logic for tag and attribute autocompletion: works out what the caret is
/// currently typing (a tag name or an attribute name) and offers matching
/// candidates. Foundation-only and unit-tested; the AppKit layer only has to
/// feed text + caret in and surface the strings out.
enum HTMLCompletion {

    enum Context: Equatable {
        case tagName(prefix: String, replace: NSRange)
        case attributeName(prefix: String, replace: NSRange)
        case none
    }

    /// Classify what the caret is typing.
    static func context(in text: String, caret: Int) -> Context {
        let ns = text as NSString
        let location = min(max(caret, 0), ns.length)

        // Find the nearest unmatched '<' before the caret (quote-aware).
        var i = location - 1
        var quote: unichar?
        var ltIndex = -1
        while i >= 0 {
            let c = ns.character(at: i)
            if let q = quote {
                if c == q { quote = nil }
            } else if c == 34 || c == 39 {
                quote = c
            } else if c == 62 { // '>' ⇒ caret is in text content, not a tag
                return .none
            } else if c == 60 { // '<'
                ltIndex = i
                break
            }
            i -= 1
        }
        guard ltIndex >= 0, quote == nil else { return .none }

        let segment = ns.substring(with: NSRange(location: ltIndex, length: location - ltIndex))
        if segment.hasPrefix("</") { return .none } // don't complete closing tags

        // Tag name: "<" followed only by name characters (no whitespace yet).
        let afterLt = String(segment.dropFirst())
        if !afterLt.contains(where: { $0 == " " || $0 == "\t" || $0 == "\n" }) {
            if afterLt.allSatisfy({ $0.isLetter || $0.isNumber || $0 == "-" || $0 == "_" || $0 == ":" }) {
                let replace = NSRange(location: ltIndex + 1, length: location - (ltIndex + 1))
                return .tagName(prefix: afterLt, replace: replace)
            }
            return .none
        }

        // Otherwise we're in the attribute area. Bail if the caret is in a value
        // (after '=' for the current word, or inside quotes — already handled).
        // Grab the current word immediately before the caret.
        var start = location
        while start > ltIndex + 1 {
            let c = ns.character(at: start - 1)
            if isNameCharCode(c) { start -= 1 } else { break }
        }
        // Char just before the word: if it's '=' we're typing a value, skip.
        if start - 1 > ltIndex {
            let before = ns.character(at: start - 1)
            if before == 61 /* = */ { return .none }
        }
        let prefix = ns.substring(with: NSRange(location: start, length: location - start))
        return .attributeName(prefix: prefix, replace: NSRange(location: start, length: location - start))
    }

    /// Tag names matching `prefix` (case-insensitive), sorted.
    static func tagCompletions(prefix: String) -> [String] {
        matches(prefix, in: tags)
    }

    /// Attribute names matching `prefix` (case-insensitive), sorted.
    static func attributeCompletions(prefix: String) -> [String] {
        matches(prefix, in: globalAttributes)
    }

    private static func matches(_ prefix: String, in pool: [String]) -> [String] {
        let p = prefix.lowercased()
        let hits = p.isEmpty ? pool : pool.filter { $0.lowercased().hasPrefix(p) }
        return hits.sorted()
    }

    private static func isNameChar(_ c: Character) -> Bool {
        c.isLetter || c.isNumber || c == "-" || c == "_" || c == ":"
    }

    private static func isNameCharCode(_ c: unichar) -> Bool {
        (c >= 65 && c <= 90) || (c >= 97 && c <= 122) || (c >= 48 && c <= 57)
            || c == 45 /* - */ || c == 95 /* _ */ || c == 58 /* : */
    }

    // MARK: - Vocabulary

    static let tags: [String] = [
        "a", "abbr", "address", "article", "aside", "audio", "b", "blockquote",
        "body", "br", "button", "canvas", "caption", "code", "col", "colgroup",
        "datalist", "dd", "del", "details", "dialog", "div", "dl", "dt", "em",
        "embed", "fieldset", "figcaption", "figure", "footer", "form",
        "h1", "h2", "h3", "h4", "h5", "h6", "head", "header", "hr", "html",
        "i", "iframe", "img", "input", "ins", "kbd", "label", "legend", "li",
        "link", "main", "map", "mark", "meta", "meter", "nav", "noscript",
        "object", "ol", "optgroup", "option", "output", "p", "picture", "pre",
        "progress", "q", "s", "samp", "script", "section", "select", "small",
        "source", "span", "strong", "style", "sub", "summary", "sup", "svg",
        "table", "tbody", "td", "template", "textarea", "tfoot", "th", "thead",
        "time", "title", "tr", "track", "u", "ul", "var", "video", "wbr"
    ]

    static let globalAttributes: [String] = [
        "accept", "accesskey", "action", "alt", "aria-hidden", "aria-label",
        "autocomplete", "autofocus", "checked", "class", "cols", "colspan",
        "content", "contenteditable", "controls", "data-", "datetime", "dir",
        "disabled", "download", "draggable", "for", "height", "href", "hidden",
        "id", "lang", "loading", "loop", "max", "maxlength", "media", "method",
        "min", "multiple", "muted", "name", "placeholder", "poster", "preload",
        "readonly", "rel", "required", "role", "rows", "rowspan", "selected",
        "sizes", "spellcheck", "src", "srcset", "step", "style", "tabindex",
        "target", "title", "type", "value", "width"
    ]
}
