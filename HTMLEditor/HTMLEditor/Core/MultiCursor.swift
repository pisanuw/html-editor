import Foundation

/// Pure computations behind multiple-cursor and column (block) selection.
/// `NSTextView` supports several selected ranges natively; these functions just
/// decide *which* ranges to select. Foundation-only and unit-tested.
enum MultiCursor {

    /// The next occurrence of `needle` at or after `location`, wrapping around
    /// to the start. Returns `nil` if `needle` does not occur.
    static func nextOccurrence(of needle: String, in text: String, after location: Int) -> NSRange? {
        guard !needle.isEmpty else { return nil }
        let ns = text as NSString
        let start = min(max(location, 0), ns.length)

        let tail = ns.range(of: needle, options: [], range: NSRange(location: start, length: ns.length - start))
        if tail.location != NSNotFound { return tail }

        let head = ns.range(of: needle, options: [], range: NSRange(location: 0, length: start))
        return head.location == NSNotFound ? nil : head
    }

    /// Append the next occurrence of `needle` to `existing`, skipping ranges
    /// already selected. Returns the combined, de-duplicated, sorted ranges, or
    /// `nil` if there is nothing new to add.
    static func addingNextOccurrence(of needle: String, in text: String, existing: [NSRange]) -> [NSRange]? {
        guard !needle.isEmpty else { return nil }
        let anchor = existing.map { $0.location + $0.length }.max() ?? 0
        var probe = anchor
        let ns = text as NSString
        // Try up to two scans (forward then wrapped) to find an unused match.
        for _ in 0..<(ns.length + 1) {
            guard let found = nextOccurrence(of: needle, in: text, after: probe) else { return nil }
            if !existing.contains(where: { NSEqualRanges($0, found) }) {
                return (existing + [found]).sorted { $0.location < $1.location }
            }
            probe = found.location + max(found.length, 1)
            if probe >= ns.length { probe = 0 }
        }
        return nil
    }

    /// One zero-length caret at the end of every line the `selection` touches.
    /// With a single empty selection this returns the caret unchanged.
    static func splitIntoLines(selection: NSRange, in text: String) -> [NSRange] {
        let ns = text as NSString
        if ns.length == 0 { return [NSRange(location: 0, length: 0)] }

        let clampedEnd = min(selection.location + selection.length, ns.length)
        var lineStart = 0, lineEnd = 0, contentEnd = 0
        var carets: [NSRange] = []
        var index = min(selection.location, ns.length)

        repeat {
            ns.getLineStart(&lineStart, end: &lineEnd, contentsEnd: &contentEnd,
                            for: NSRange(location: index, length: 0))
            carets.append(NSRange(location: contentEnd, length: 0))
            index = lineEnd
        } while index < clampedEnd && index < ns.length

        return carets.isEmpty ? [NSRange(location: selection.location, length: 0)] : carets
    }

    /// A block of selections spanning the lines between the start and end of
    /// `selection`, each from the start column to the end column of `selection`
    /// (clamped to the line). When the columns are equal this yields a caret on
    /// each line at that column. Useful as a keyboard-driven column selection.
    static func columnSelections(for selection: NSRange, in text: String) -> [NSRange] {
        let ns = text as NSString
        let startLoc = min(selection.location, ns.length)
        let endLoc = min(selection.location + selection.length, ns.length)

        let (startLineStart, startCol) = lineStartAndColumn(ns, at: startLoc)
        let (_, endCol) = lineStartAndColumn(ns, at: endLoc)
        let loCol = min(startCol, endCol)
        let hiCol = max(startCol, endCol)

        var ranges: [NSRange] = []
        var lineStart = startLineStart
        while lineStart <= endLoc {
            var ls = 0, le = 0, ce = 0
            ns.getLineStart(&ls, end: &le, contentsEnd: &ce, for: NSRange(location: lineStart, length: 0))
            let lineLength = ce - ls
            let from = ls + min(loCol, lineLength)
            let to = ls + min(hiCol, lineLength)
            ranges.append(NSRange(location: from, length: to - from))
            if le == lineStart { break }   // no progress (last line)
            lineStart = le
        }
        return ranges
    }

    // MARK: - Helpers

    private static func lineStartAndColumn(_ ns: NSString, at location: Int) -> (lineStart: Int, column: Int) {
        var ls = 0, le = 0, ce = 0
        ns.getLineStart(&ls, end: &le, contentsEnd: &ce, for: NSRange(location: min(location, ns.length), length: 0))
        return (ls, location - ls)
    }
}
