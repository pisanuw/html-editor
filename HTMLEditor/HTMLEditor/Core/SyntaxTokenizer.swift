import Foundation

/// A semantic classification for a span of source text.
///
/// The tokenizer is intentionally lightweight and regex-based, matching the
/// project's "simple and easy to understand" philosophy. It is *not* a full
/// parser — it produces non-overlapping tokens suitable for syntax coloring.
enum TokenType: String, Equatable, CaseIterable {
    // HTML
    case doctype
    case comment
    case tag
    case attribute
    case string

    // CSS
    case cssSelector
    case cssProperty
    case cssValue
    case cssComment

    // JavaScript
    case jsKeyword
    case jsString
    case jsComment
    case jsNumber
}

/// A classified span of text. `range` is expressed in UTF-16 offsets so it can
/// be applied directly to an `NSTextStorage` / `NSAttributedString`.
struct Token: Equatable {
    let type: TokenType
    let range: NSRange
}

/// Produces `[Token]` for HTML documents, including embedded CSS (`<style>`)
/// and JavaScript (`<script>`). Pure: depends only on Foundation so it can be
/// unit-tested without AppKit.
enum SyntaxTokenizer {

    /// A single coloring rule: a compiled-on-demand pattern plus the token type
    /// it produces. `captureGroup` lets a rule color a sub-capture instead of
    /// the whole match (used for CSS values).
    private struct Rule {
        let type: TokenType
        let pattern: String
        let options: NSRegularExpression.Options
        let captureGroup: Int

        init(_ type: TokenType,
             _ pattern: String,
             options: NSRegularExpression.Options = [],
             captureGroup: Int = 0) {
            self.type = type
            self.pattern = pattern
            self.options = options
            self.captureGroup = captureGroup
        }
    }

    // MARK: - Public API

    /// Tokenize an entire HTML document.
    static func tokenize(_ text: String) -> [Token] {
        let ns = text as NSString
        guard ns.length > 0 else { return [] }
        let full = NSRange(location: 0, length: ns.length)

        var tokens: [Token] = []
        var consumed = IndexSet()

        // 1. Embedded languages first so their inner content is claimed before
        //    the HTML rules run over the whole document. After tokenizing each
        //    region we mask its *entire* interior so the HTML rules can't color
        //    un-claimed fragments (e.g. a JS identifier that looks like an
        //    HTML attribute).
        for region in embeddedRegions(in: text, type: "style") {
            collect(into: &tokens, consumed: &consumed,
                    rules: cssRules, text: text, within: region)
            mask(region, in: &consumed)
        }
        for region in embeddedRegions(in: text, type: "script") {
            collect(into: &tokens, consumed: &consumed,
                    rules: jsRules, text: text, within: region)
            mask(region, in: &consumed)
        }

        // 2. HTML rules over the full document (already-consumed inner ranges
        //    of <style>/<script> are skipped, but their tags are still colored).
        collect(into: &tokens, consumed: &consumed,
                rules: htmlRules, text: text, within: full)

        return tokens.sorted { $0.range.location < $1.range.location }
    }

    // MARK: - Rule sets

    private static let htmlRules: [Rule] = [
        Rule(.comment, "<!--[\\s\\S]*?-->"),
        Rule(.doctype, "<!DOCTYPE[^>]*>", options: .caseInsensitive),
        Rule(.string, "\"[^\"\\n]*\""),
        Rule(.string, "'[^'\\n]*'"),
        Rule(.tag, "</?[a-zA-Z][a-zA-Z0-9-]*"),
        Rule(.tag, "/?>"),
        Rule(.attribute, "[a-zA-Z_:][a-zA-Z0-9_:.-]*(?=\\s*=)")
    ]

    private static let cssRules: [Rule] = [
        Rule(.cssComment, "/\\*[\\s\\S]*?\\*/"),
        Rule(.string, "\"[^\"\\n]*\""),
        Rule(.string, "'[^'\\n]*'"),
        Rule(.cssProperty, "[a-zA-Z-]+(?=\\s*:)"),
        Rule(.cssValue, ":\\s*([^;{}\\n]+)", captureGroup: 1),
        Rule(.cssSelector, "[^{}();\\n]+(?=\\s*\\{)")
    ]

    private static let jsRules: [Rule] = [
        Rule(.jsComment, "//[^\\n]*"),
        Rule(.jsComment, "/\\*[\\s\\S]*?\\*/"),
        Rule(.jsString, "\"[^\"\\n]*\""),
        Rule(.jsString, "'[^'\\n]*'"),
        Rule(.jsString, "`[^`]*`"),
        Rule(.jsKeyword,
             "\\b(var|let|const|function|return|if|else|for|while|do|switch|"
             + "case|default|break|continue|new|class|extends|super|this|"
             + "typeof|instanceof|in|of|try|catch|finally|throw|await|async|"
             + "yield|delete|void|null|true|false|undefined|import|export|from)\\b"),
        Rule(.jsNumber, "\\b\\d+(?:\\.\\d+)?\\b")
    ]

    // MARK: - Engine

    /// Apply `rules` in precedence order within `region`, emitting tokens that
    /// do not overlap any previously consumed range.
    private static func collect(into tokens: inout [Token],
                                consumed: inout IndexSet,
                                rules: [Rule],
                                text: String,
                                within region: NSRange) {
        for rule in rules {
            guard let regex = try? NSRegularExpression(pattern: rule.pattern,
                                                       options: rule.options)
            else { continue }
            let matches = regex.matches(in: text, range: region)
            for match in matches {
                let r = match.range(at: rule.captureGroup)
                guard r.location != NSNotFound, r.length > 0 else { continue }
                let lower = r.location
                let upper = r.location + r.length
                // Skip if any offset in the range is already claimed.
                if consumed.intersects(integersIn: lower..<upper) { continue }
                consumed.insert(integersIn: lower..<upper)
                tokens.append(Token(type: rule.type, range: r))
            }
        }
    }

    /// Mark an entire range as consumed so later rule sets skip it.
    private static func mask(_ range: NSRange, in consumed: inout IndexSet) {
        guard range.length > 0 else { return }
        consumed.insert(integersIn: range.location..<(range.location + range.length))
    }

    /// Find the inner-content ranges (between the open and close tags) of all
    /// `<tagName>…</tagName>` blocks. Used to route CSS/JS to their tokenizers.
    private static func embeddedRegions(in text: String, type tagName: String) -> [NSRange] {
        let pattern = "<\(tagName)\\b[^>]*>([\\s\\S]*?)</\(tagName)>"
        guard let regex = try? NSRegularExpression(pattern: pattern,
                                                   options: .caseInsensitive)
        else { return [] }
        let ns = text as NSString
        let full = NSRange(location: 0, length: ns.length)
        return regex.matches(in: text, range: full).compactMap { match in
            let inner = match.range(at: 1)
            return inner.location != NSNotFound && inner.length > 0 ? inner : nil
        }
    }
}

private extension IndexSet {
    /// True if any integer in `range` is already present in the set.
    func intersects(integersIn range: Range<Int>) -> Bool {
        guard !range.isEmpty else { return false }
        return !self.intersection(IndexSet(integersIn: range)).isEmpty
    }
}
