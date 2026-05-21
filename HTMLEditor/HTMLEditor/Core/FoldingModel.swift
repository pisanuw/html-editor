import Foundation

/// Pure folding logic built on `CodeStructure.foldableRegions`. Given the text
/// and which toggle lines are currently folded, it computes the (merged)
/// character ranges that should be hidden. The AppKit layer turns these into
/// suppressed glyphs; the gutter uses the toggle lines for fold controls.
enum FoldingModel {

    static func regions(in text: String) -> [CodeStructure.FoldRegion] {
        CodeStructure.foldableRegions(in: text)
    }

    /// Toggle lines (0-based) that have a foldable region.
    static func foldableToggleLines(in text: String) -> Set<Int> {
        Set(regions(in: text).map { $0.toggleLine })
    }

    static func region(forToggleLine line: Int, in text: String) -> CodeStructure.FoldRegion? {
        regions(in: text).first { $0.toggleLine == line }
    }

    /// Merged character ranges to hide for the given set of folded toggle lines.
    static func hiddenRanges(in text: String, foldedToggleLines: Set<Int>) -> [NSRange] {
        let ranges = regions(in: text)
            .filter { foldedToggleLines.contains($0.toggleLine) }
            .map { $0.range }
        return merge(ranges)
    }

    /// Merge overlapping/adjacent ranges into a minimal sorted set.
    static func merge(_ ranges: [NSRange]) -> [NSRange] {
        let sorted = ranges.sorted { $0.location < $1.location }
        var out: [NSRange] = []
        for r in sorted {
            if let last = out.last, r.location <= last.location + last.length {
                let end = max(last.location + last.length, r.location + r.length)
                out[out.count - 1] = NSRange(location: last.location, length: end - last.location)
            } else {
                out.append(r)
            }
        }
        return out
    }
}
