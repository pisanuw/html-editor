import Foundation

struct ValidationIssue: Identifiable {
    enum Severity { case error, warning }
    let id = UUID()
    let severity: Severity
    let message: String
    let line: Int
}

/// Validates HTML for structural correctness and common attribute mistakes.
/// Pure and Foundation-only; all checks are conservative (no false positives
/// for optional-close elements like <p>, <li>, <td>, etc.).
enum HTMLValidator {

    static func validate(_ html: String) -> [ValidationIssue] {
        var issues: [ValidationIssue] = []
        let ns = html as NSString
        var stack: [(tag: String, line: Int)] = []
        var i = 0
        var lineNumber = 1

        while i < ns.length {
            let c = ns.character(at: i)
            if c == 10 { lineNumber += 1; i += 1; continue }
            guard c == 60 else { i += 1; continue } // '<'

            let tagLine = lineNumber
            i += 1
            guard i < ns.length else { break }
            let next = ns.character(at: i)

            // Closing tag </tag>
            if next == 47 {
                i += 1
                let name = readTagName(ns, from: &i)
                skipToClose(ns, from: &i)
                guard !name.isEmpty else { continue }
                if let idx = stack.lastIndex(where: { $0.tag == name }) {
                    // Flag any non-optional unclosed tags between matching close and current top.
                    for s in stack[(idx + 1)...] where !optionalClose.contains(s.tag) {
                        issues.append(ValidationIssue(severity: .error,
                                                      message: "Unclosed <\(s.tag)>",
                                                      line: s.line))
                    }
                    stack.removeSubrange(idx...)
                } else if !optionalClose.contains(name) {
                    issues.append(ValidationIssue(severity: .error,
                                                  message: "Unexpected </\(name)>",
                                                  line: tagLine))
                }
                continue
            }

            // Comment or doctype — skip to '>'
            if next == 33 || next == 63 { skipToClose(ns, from: &i); continue }

            let name = readTagName(ns, from: &i)
            guard !name.isEmpty else { i += 1; continue }

            var attrs: [String: Bool] = [:]
            var selfClose = false
            readAttributeNames(ns, from: &i, into: &attrs, selfClose: &selfClose)

            // Per-element attribute checks.
            if name == "img" && attrs["alt"] == nil {
                issues.append(ValidationIssue(severity: .warning,
                                              message: "<img> missing alt attribute",
                                              line: tagLine))
            }
            if name == "a" && attrs["href"] == nil && attrs["name"] == nil && attrs["id"] == nil {
                issues.append(ValidationIssue(severity: .warning,
                                              message: "<a> missing href attribute",
                                              line: tagLine))
            }

            if !selfClose && !voidElements.contains(name) {
                stack.append((tag: name, line: tagLine))
            }
        }

        // Any remaining non-optional tags are unclosed.
        for entry in stack.reversed()
            where !optionalClose.contains(entry.tag)
               && entry.tag != "html" && entry.tag != "head" && entry.tag != "body" {
            issues.append(ValidationIssue(severity: .error,
                                          message: "Unclosed <\(entry.tag)>",
                                          line: entry.line))
        }

        return issues.sorted { $0.line < $1.line }
    }

    // MARK: - Helpers

    private static func readTagName(_ ns: NSString, from i: inout Int) -> String {
        var buf = ""
        while i < ns.length {
            let c = ns.character(at: i)
            guard (c >= 65 && c <= 90) || (c >= 97 && c <= 122) || (c >= 48 && c <= 57)
                    || c == 45 || c == 95 || c == 58 else { break }
            buf.unicodeScalars.append(Unicode.Scalar(c)!)
            i += 1
        }
        return buf.lowercased()
    }

    /// Scan past attributes, recording which attribute names are present.
    private static func readAttributeNames(_ ns: NSString, from i: inout Int,
                                           into attrs: inout [String: Bool],
                                           selfClose: inout Bool) {
        var inQuote: unichar? = nil
        var key = ""

        while i < ns.length {
            let c = ns.character(at: i)
            if let q = inQuote {
                if c == q { inQuote = nil }
                i += 1; continue
            }
            if c == 62 { // >
                if !key.isEmpty { attrs[key] = true }
                selfClose = i > 0 && ns.character(at: i - 1) == 47
                i += 1; return
            }
            if c == 47 { i += 1; continue } // trailing slash before >
            if c == 34 || c == 39 { inQuote = c; i += 1; continue }
            if c == 61 { // = means value follows; key is complete
                if !key.isEmpty { attrs[key] = true; key = "" }
                i += 1; continue
            }
            if c == 32 || c == 9 || c == 10 || c == 13 {
                if !key.isEmpty { attrs[key] = true; key = "" }
                i += 1; continue
            }
            key.unicodeScalars.append(Unicode.Scalar(c)!)
            i += 1
        }
        selfClose = false
    }

    private static func skipToClose(_ ns: NSString, from i: inout Int) {
        while i < ns.length { let c = ns.character(at: i); i += 1; if c == 62 { return } }
    }

    private static let voidElements: Set<String> = [
        "area", "base", "br", "col", "embed", "hr", "img", "input",
        "link", "meta", "param", "source", "track", "wbr"
    ]

    private static let optionalClose: Set<String> = [
        "li", "dt", "dd", "p", "rb", "rt", "rtc", "rp",
        "optgroup", "option", "colgroup", "caption",
        "thead", "tbody", "tfoot", "tr", "th", "td"
    ]
}
