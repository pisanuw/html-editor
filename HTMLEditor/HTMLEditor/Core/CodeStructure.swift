import Foundation

/// Pure structural helpers for the editor: matching `()[]{}` brackets, and
/// computing which tag pairs form foldable (multi-line) regions. The AppKit
/// layer turns these ranges into highlight attributes and fold affordances.
enum CodeStructure {

    private static let openToClose: [unichar: unichar] = [40: 41, 91: 93, 123: 125] // ( [ {
    private static let closeToOpen: [unichar: unichar] = [41: 40, 93: 91, 125: 123]

    /// The pair of single-character ranges for the bracket at (or just before)
    /// the caret and its partner, or `nil` if the caret is not on a bracket or
    /// the bracket is unbalanced. Returned as (openRange, closeRange).
    static func matchingBracket(in text: String, caret: Int) -> (NSRange, NSRange)? {
        let ns = text as NSString
        func char(at i: Int) -> unichar? { (i >= 0 && i < ns.length) ? ns.character(at: i) : nil }

        for probe in [caret - 1, caret] {
            guard let c = char(at: probe) else { continue }
            if let close = openToClose[c] {
                if let match = scanForward(ns, from: probe + 1, open: c, close: close) {
                    return (NSRange(location: probe, length: 1), NSRange(location: match, length: 1))
                }
            } else if let open = closeToOpen[c] {
                if let match = scanBackward(ns, from: probe - 1, open: open, close: c) {
                    return (NSRange(location: match, length: 1), NSRange(location: probe, length: 1))
                }
            }
        }
        return nil
    }

    private static func scanForward(_ ns: NSString, from start: Int, open: unichar, close: unichar) -> Int? {
        var depth = 1
        var j = start
        while j < ns.length {
            let c = ns.character(at: j)
            if c == open { depth += 1 }
            else if c == close { depth -= 1; if depth == 0 { return j } }
            j += 1
        }
        return nil
    }

    private static func scanBackward(_ ns: NSString, from start: Int, open: unichar, close: unichar) -> Int? {
        var depth = 1
        var j = start
        while j >= 0 {
            let c = ns.character(at: j)
            if c == close { depth += 1 }
            else if c == open { depth -= 1; if depth == 0 { return j } }
            j -= 1
        }
        return nil
    }

    // MARK: - Folding

    struct FoldRegion: Equatable {
        /// Zero-based line index of the opening tag (where the fold control sits).
        let toggleLine: Int
        /// The collapsible inner range (between the open and close tags).
        let range: NSRange
    }

    /// Multi-line tag pairs that can be folded, sorted by position. Uses a
    /// lenient name-matched stack so mismatched/unclosed tags are skipped rather
    /// than throwing the rest off.
    static func foldableRegions(in text: String) -> [FoldRegion] {
        let ns = text as NSString
        let tokens = TagEditing.scanTags(text)
        var stack: [Int] = []
        var result: [FoldRegion] = []

        for (idx, token) in tokens.enumerated() {
            switch token.kind {
            case .open:
                stack.append(idx)
            case .close:
                guard let top = stack.lastIndex(where: { tokens[$0].name == token.name }) else { continue }
                let openToken = tokens[stack[top]]
                stack.removeSubrange(top...)
                let openEnd = openToken.range.location + openToken.range.length
                let closeStart = token.range.location
                guard closeStart > openEnd else { continue }
                let inner = NSRange(location: openEnd, length: closeStart - openEnd)
                if ns.substring(with: inner).contains("\n") {
                    result.append(FoldRegion(toggleLine: lineIndex(ns, at: openToken.range.location), range: inner))
                }
            case .selfClose, .voidEl:
                break
            }
        }
        return result.sorted { $0.range.location < $1.range.location }
    }

    private static func lineIndex(_ ns: NSString, at location: Int) -> Int {
        var count = 0
        let upper = min(location, ns.length)
        var i = 0
        while i < upper {
            if ns.character(at: i) == 10 /* \n */ { count += 1 }
            i += 1
        }
        return count
    }
}
