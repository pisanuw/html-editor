import Foundation

/// Pure text measurement helpers. Extracted from the document model so the
/// line/column math can be unit-tested without AppKit.
enum TextMetrics {

    /// 1-based line and column for a UTF-16 offset `location` within `string`.
    /// Out-of-range offsets are clamped to the string length.
    static func lineColumn(in string: String, at location: Int) -> (line: Int, column: Int) {
        let ns = string as NSString
        let end = max(0, min(location, ns.length))
        var line = 1
        var lineStart = 0
        var i = 0
        while i < end {
            if ns.character(at: i) == 10 { // '\n'
                line += 1
                lineStart = i + 1
            }
            i += 1
        }
        return (line, end - lineStart + 1)
    }

    /// Total number of lines in `string` (a trailing newline does not add an
    /// extra empty line for display purposes).
    static func lineCount(in string: String) -> Int {
        guard !string.isEmpty else { return 1 }
        let ns = string as NSString
        var count = 1
        for i in 0..<ns.length where ns.character(at: i) == 10 {
            count += 1
        }
        // A document ending in a newline shows a final empty line in the editor,
        // so the raw count is what the gutter should display.
        return count
    }
}
