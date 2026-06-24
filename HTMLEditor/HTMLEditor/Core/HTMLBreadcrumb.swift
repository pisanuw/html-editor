import Foundation

/// Computes the HTML element path at a given character offset by walking
/// backwards through the source. Pure and Foundation-only.
///
/// Example: for a cursor inside `<div><p>|text</p></div>` returns
/// `["div", "p"]`.
enum HTMLBreadcrumb {

    static func path(in text: String, at location: Int) -> [String] {
        let ns = text as NSString
        let end = min(location, ns.length)
        var stack: [String] = []
        var i = 0

        while i < end {
            let c = ns.character(at: i)
            // Opening "<"
            guard c == 60 else { i += 1; continue }
            i += 1
            guard i < end else { break }

            let next = ns.character(at: i)

            // Closing tag </tag>
            if next == 47 /* / */ {
                i += 1
                let name = readName(ns, from: &i, limit: end)
                if !name.isEmpty, let idx = stack.lastIndex(of: name) {
                    stack.removeSubrange(idx...)
                }
                skipToClose(ns, from: &i, limit: end)
                continue
            }

            // Comment or doctype — skip
            if next == 33 /* ! */ {
                skipToClose(ns, from: &i, limit: end)
                continue
            }

            // Opening tag <tag ...>
            let name = readName(ns, from: &i, limit: end)
            guard !name.isEmpty else { i += 1; continue }

            // Peek ahead to see if it's a self-closing tag or a void element.
            skipPastAttributes(ns, from: &i, limit: end)
            let selfClose = i > 0 && ns.character(at: i - 1) == 47  // ended on '/'
            if !selfClose && !voidElements.contains(name) {
                stack.append(name)
            }
        }

        return stack
    }

    // MARK: - Helpers

    private static func readName(_ ns: NSString, from i: inout Int, limit: Int) -> String {
        var buf = ""
        while i < limit {
            let c = ns.character(at: i)
            // Name chars: letter, digit, hyphen, underscore, colon
            if (c >= 65 && c <= 90) || (c >= 97 && c <= 122) || (c >= 48 && c <= 57)
                || c == 45 || c == 95 || c == 58 {
                buf.unicodeScalars.append(Unicode.Scalar(c)!)
                i += 1
            } else {
                break
            }
        }
        return buf.lowercased()
    }

    /// Skip whitespace, attribute key=value pairs, until '>' or '/>' or end.
    private static func skipPastAttributes(_ ns: NSString, from i: inout Int, limit: Int) {
        var inQuote: unichar?
        while i < limit {
            let c = ns.character(at: i)
            if let q = inQuote {
                if c == q { inQuote = nil }
                i += 1
            } else if c == 34 || c == 39 {
                inQuote = c
                i += 1
            } else if c == 62 /* > */ {
                i += 1
                return
            } else {
                i += 1
            }
        }
    }

    private static func skipToClose(_ ns: NSString, from i: inout Int, limit: Int) {
        while i < limit {
            let c = ns.character(at: i)
            i += 1
            if c == 62 { return }
        }
    }

    private static let voidElements: Set<String> = [
        "area", "base", "br", "col", "embed", "hr", "img", "input",
        "link", "meta", "param", "source", "track", "wbr"
    ]
}
