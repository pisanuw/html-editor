import Foundation

/// Pure HTML-tag editing helpers: auto-closing a tag when the user types `>`,
/// and locating the name ranges of a tag and its matching partner (used for
/// linked rename via multi-selection). Foundation-only and unit-tested.
enum TagEditing {

    static let voidTags = EmmetExpander.voidTags

    /// What to insert after the user types the `>` that closes an opening tag.
    struct CloseResult: Equatable {
        /// The closing tag to insert at the caret, e.g. `</div>`.
        let closing: String
        /// Where the caret should sit afterwards (between `>` and the closing
        /// tag, i.e. unchanged from where the `>` left it).
        let caret: Int
    }

    /// Given text whose caret sits immediately *after* a just-typed `>`,
    /// returns the closing tag to insert, or `nil` when auto-closing does not
    /// apply (closing tag, self-closing, void element, comment/doctype, or an
    /// already-present matching close).
    static func autoClose(in text: String, caretAfterBracket caret: Int) -> CloseResult? {
        let ns = text as NSString
        guard caret >= 2, caret <= ns.length, ns.character(at: caret - 1) == 62 /* > */ else { return nil }

        // Walk back to the matching '<', honoring quotes, with no nested '<'.
        var i = caret - 2
        var quote: unichar?
        var ltIndex = -1
        while i >= 0 {
            let c = ns.character(at: i)
            if let q = quote {
                if c == q { quote = nil }
            } else if c == 34 || c == 39 { // " or '
                quote = c
            } else if c == 62 { // another '>' before we found '<' ⇒ not a clean tag
                return nil
            } else if c == 60 { // <
                ltIndex = i
                break
            }
            i -= 1
        }
        guard ltIndex >= 0, quote == nil else { return nil }

        let inner = ns.substring(with: NSRange(location: ltIndex + 1, length: caret - 2 - ltIndex))
        guard let name = openingTagName(inner) else { return nil }
        guard !voidTags.contains(name.lowercased()) else { return nil }

        // Skip if a matching close already immediately follows.
        let rest = ns.substring(from: caret)
        if rest.hasPrefix("</\(name)>") || rest.hasPrefix("</\(name) ") { return nil }

        return CloseResult(closing: "</\(name)>", caret: caret)
    }

    /// Name of the opening tag described by the text between `<` and `>`, or
    /// `nil` if it is a closing tag, comment, doctype, or self-closing.
    private static func openingTagName(_ inner: String) -> String? {
        guard let first = inner.first, first != "/", first != "!", first != "?" else { return nil }
        if inner.hasSuffix("/") { return nil } // self-closing
        var name = ""
        for c in inner {
            if c.isLetter || c.isNumber || c == "-" || c == "_" || c == ":" { name.append(c) } else { break }
        }
        return name.isEmpty ? nil : name
    }

    // MARK: - Matching tag (linked rename)

    enum Kind { case open, close, selfClose, voidEl }

    struct TagToken: Equatable {
        let range: NSRange      // whole `<…>`
        let nameRange: NSRange  // just the tag name
        let name: String
        let kind: Kind
    }

    /// Name ranges of the tag under `caret` and its matching partner, suitable
    /// for selecting both so a rename edits them together. Returns `nil` for
    /// self-closing/void tags or when no partner exists.
    static func matchingTagNameRanges(in text: String, caret: Int) -> (NSRange, NSRange)? {
        let tokens = scanTags(text)
        guard let here = tokens.firstIndex(where: {
            NSLocationInRange(caret, $0.range) || caret == $0.range.location + $0.range.length
        }) else {
            return nil
        }
        let token = tokens[here]
        switch token.kind {
        case .selfClose, .voidEl:
            return nil
        case .open:
            guard let partner = matchForward(from: here, in: tokens) else { return nil }
            return (token.nameRange, tokens[partner].nameRange)
        case .close:
            guard let partner = matchBackward(from: here, in: tokens) else { return nil }
            return (tokens[partner].nameRange, token.nameRange)
        }
    }

    private static func matchForward(from index: Int, in tokens: [TagToken]) -> Int? {
        let name = tokens[index].name
        var depth = 0
        var j = index + 1
        while j < tokens.count {
            let t = tokens[j]
            if t.name == name {
                if t.kind == .open { depth += 1 } else if t.kind == .close {
                    if depth == 0 { return j }
                    depth -= 1
                }
            }
            j += 1
        }
        return nil
    }

    private static func matchBackward(from index: Int, in tokens: [TagToken]) -> Int? {
        let name = tokens[index].name
        var depth = 0
        var j = index - 1
        while j >= 0 {
            let t = tokens[j]
            if t.name == name {
                if t.kind == .close { depth += 1 } else if t.kind == .open {
                    if depth == 0 { return j }
                    depth -= 1
                }
            }
            j -= 1
        }
        return nil
    }

    /// All `<…>` tags in `text` with their kinds and name ranges. Comments and
    /// doctypes are skipped. Quote-aware so `>` inside an attribute value does
    /// not end a tag.
    static func scanTags(_ text: String) -> [TagToken] {
        let ns = text as NSString
        var tokens: [TagToken] = []
        var i = 0
        while i < ns.length {
            guard ns.character(at: i) == 60 /* < */ else { i += 1; continue }

            // Skip comments and doctype/processing instructions.
            let next = i + 1 < ns.length ? ns.character(at: i + 1) : 0
            if next == 33 /* ! */ || next == 63 /* ? */ {
                if ns.length >= i + 4,
                   ns.character(at: i + 2) == 45 /* - */,
                   ns.character(at: i + 3) == 45 /* - */ {
                    // HTML comment: ends at "-->", not the first '>'.
                    let close = ns.range(of: "-->", options: [],
                                         range: NSRange(location: i + 4, length: ns.length - (i + 4)))
                    if close.location != NSNotFound { i = close.location + close.length } else { break }
                } else if let end = indexAfterTagEnd(ns, from: i) {
                    i = end
                } else { break }
                continue
            }

            guard let endExclusive = indexAfterTagEnd(ns, from: i) else { break }
            let inner = ns.substring(with: NSRange(location: i + 1, length: endExclusive - i - 2))
            if let token = makeToken(inner: inner, ltIndex: i, wholeLength: endExclusive - i) {
                tokens.append(token)
            }
            i = endExclusive
        }
        return tokens
    }

    /// Index just past the closing `>` of the tag starting at `start`, honoring
    /// quotes. Returns `nil` if unterminated.
    private static func indexAfterTagEnd(_ ns: NSString, from start: Int) -> Int? {
        var i = start + 1
        var quote: unichar?
        while i < ns.length {
            let c = ns.character(at: i)
            if let q = quote {
                if c == q { quote = nil }
            } else if c == 34 || c == 39 {
                quote = c
            } else if c == 62 { // >
                return i + 1
            }
            i += 1
        }
        return nil
    }

    private static func makeToken(inner: String, ltIndex: Int, wholeLength: Int) -> TagToken? {
        let whole = NSRange(location: ltIndex, length: wholeLength)
        let isClose = inner.hasPrefix("/")
        let isSelf = inner.hasSuffix("/")
        let body = isClose ? String(inner.dropFirst()) : inner

        var name = ""
        for c in body {
            if c.isLetter || c.isNumber || c == "-" || c == "_" || c == ":" { name.append(c) } else { break }
        }
        guard !name.isEmpty else { return nil }

        // Name starts after '<' (+1 for '/').
        let nameStart = ltIndex + 1 + (isClose ? 1 : 0)
        let nameRange = NSRange(location: nameStart, length: (name as NSString).length)

        let kind: Kind
        if isClose {
            kind = .close
        } else if isSelf {
            kind = .selfClose
        } else if voidTags.contains(name.lowercased()) {
            kind = .voidEl
        } else {
            kind = .open
        }

        return TagToken(range: whole, nameRange: nameRange, name: name, kind: kind)
    }
}
