import Foundation

/// Produces structured search hits for one document so the "find across all
/// tabs" results list can show a line number and a preview of each match. The
/// UI runs this per open document and groups the results; keeping it per-text
/// keeps the logic pure and unit-testable.
enum MultiFileSearch {

    struct Hit: Equatable {
        let range: NSRange     // UTF-16 range of the match in the document
        let line: Int          // 1-based line number
        let lineText: String   // trimmed text of the line containing the match
    }

    static func hits(in text: String, query: String, options: FindOptions = FindOptions()) -> [Hit] {
        let ns = text as NSString
        return FindEngine.matches(in: text, query: query, options: options).map { range in
            let lineRange = ns.lineRange(for: NSRange(location: range.location, length: 0))
            let lineText = ns.substring(with: lineRange).trimmingCharacters(in: .whitespacesAndNewlines)
            let line = TextMetrics.lineColumn(in: text, at: range.location).line
            return Hit(range: range, line: line, lineText: lineText)
        }
    }
}
