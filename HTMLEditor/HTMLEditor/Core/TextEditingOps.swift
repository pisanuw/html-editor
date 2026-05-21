import Foundation

/// Pure, side-effect-free editor text transforms used by the editor's key
/// handling (Tab / Shift-Tab / Return). Each function takes the current text
/// and selection (UTF-16 `NSRange`) and returns the resulting text and the new
/// selection. No AppKit dependency, so these are fully unit-testable.
enum TextEditingOps {

    /// The result of an edit: the full replacement text and where the selection
    /// should land afterwards.
    struct EditResult: Equatable {
        let text: String
        let selection: NSRange
    }

    static let defaultIndentWidth = 2

    private static func unit(_ width: Int) -> String {
        String(repeating: " ", count: max(1, width))
    }

    // MARK: - Tab

    /// Behavior of the Tab key.
    ///
    /// - With an empty selection: insert one indent unit at the caret.
    /// - With any non-empty selection: indent every line the selection touches
    ///   (Tab acts as a block-indent).
    static func insertTab(in text: String,
                          selection: NSRange,
                          indentWidth: Int = defaultIndentWidth) -> EditResult {
        if selection.length == 0 {
            let pad = unit(indentWidth)
            let new = replacing(text, range: selection, with: pad)
            let caret = NSRange(location: selection.location + (pad as NSString).length, length: 0)
            return EditResult(text: new, selection: caret)
        }
        return indentLines(in: text, selection: selection, indentWidth: indentWidth)
    }

    /// Indent every line touched by `selection` by one unit.
    static func indentLines(in text: String,
                            selection: NSRange,
                            indentWidth: Int = defaultIndentWidth) -> EditResult {
        let pad = unit(indentWidth)
        let padLen = (pad as NSString).length
        let ns = text as NSString
        let lineRange = ns.lineRange(for: selection)
        let block = ns.substring(with: lineRange)

        var firstLineAdded = 0
        var addedAfterFirst = 0
        var isFirst = true
        let rebuilt = mapLines(block) { line in
            defer { isFirst = false }
            guard !line.isEmpty else { return line } // don't pad blank lines
            if isFirst { firstLineAdded = padLen } else { addedAfterFirst += padLen }
            return pad + line
        }

        let new = ns.replacingCharacters(in: lineRange, with: rebuilt)
        let newLoc = selection.location + firstLineAdded
        let newLen = selection.length + addedAfterFirst
        return EditResult(text: new, selection: NSRange(location: newLoc, length: newLen))
    }

    /// Remove up to one indent unit from the start of every line touched by
    /// `selection`. Lines with less leading whitespace lose only what they have.
    static func outdentLines(in text: String,
                             selection: NSRange,
                             indentWidth: Int = defaultIndentWidth) -> EditResult {
        let width = max(1, indentWidth)
        let ns = text as NSString
        let lineRange = ns.lineRange(for: selection)
        let block = ns.substring(with: lineRange)

        var firstLineRemoved = 0
        var isFirstLine = true
        var removedAfterFirst = 0

        let rebuilt = mapLines(block) { line in
            let removed = leadingWhitespaceToRemove(line, max: width)
            if isFirstLine {
                firstLineRemoved = removed
                isFirstLine = false
            } else {
                removedAfterFirst += removed
            }
            return String(line.dropFirst(removed))
        }

        let new = ns.replacingCharacters(in: lineRange, with: rebuilt)
        let newLoc = max(lineRange.location, selection.location - firstLineRemoved)
        let newLen = max(0, selection.length - removedAfterFirst)
        return EditResult(text: new, selection: NSRange(location: newLoc, length: newLen))
    }

    // MARK: - Return / newline

    /// Smart newline: insert a line break, then reproduce the current line's
    /// leading whitespace. If the caret sits immediately after an opening
    /// construct (`>` of a non-closing tag, or `{`), add one extra indent unit.
    static func insertNewline(in text: String,
                              selection: NSRange,
                              indentWidth: Int = defaultIndentWidth) -> EditResult {
        let ns = text as NSString
        let caret = selection.location
        let lineStart = lineStartIndex(ns, before: caret)
        let currentLine = ns.substring(with: NSRange(location: lineStart, length: caret - lineStart))
        var indent = leadingWhitespace(currentLine)

        if shouldIncreaseIndent(beforeCaret: currentLine) {
            indent += unit(indentWidth)
        }

        let insertion = "\n" + indent
        let new = replacing(text, range: selection, with: insertion)
        let caretLoc = selection.location + (insertion as NSString).length
        return EditResult(text: new, selection: NSRange(location: caretLoc, length: 0))
    }

    // MARK: - Helpers

    private static func replacing(_ text: String, range: NSRange, with replacement: String) -> String {
        (text as NSString).replacingCharacters(in: range, with: replacement)
    }

    private static func leadingWhitespace(_ line: String) -> String {
        var result = ""
        for ch in line {
            if ch == " " || ch == "\t" { result.append(ch) } else { break }
        }
        return result
    }

    /// How many leading whitespace characters to strip, up to `max`. A tab
    /// counts as a single removable character.
    private static func leadingWhitespaceToRemove(_ line: String, max: Int) -> Int {
        var count = 0
        for ch in line {
            if count >= max { break }
            if ch == " " || ch == "\t" { count += 1 } else { break }
        }
        return count
    }

    private static func shouldIncreaseIndent(beforeCaret line: String) -> Bool {
        let trimmed = line.trimmingCharacters(in: .whitespaces)
        guard let last = trimmed.last else { return false }
        if last == "{" { return true }
        guard last == ">" else { return false }
        if trimmed.hasSuffix("/>") { return false }          // self-closing tag
        guard let openIdx = trimmed.lastIndex(of: "<") else { return false }
        let afterOpen = trimmed.index(after: openIdx)
        if afterOpen < trimmed.endIndex, trimmed[afterOpen] == "/" { return false } // closing tag
        return true                                          // opening tag
    }

    private static func lineStartIndex(_ ns: NSString, before location: Int) -> Int {
        var i = min(location, ns.length) - 1
        while i >= 0 {
            if ns.character(at: i) == 10 { return i + 1 } // '\n'
            i -= 1
        }
        return 0
    }

    /// Apply `transform` to each line of `block`, preserving the exact original
    /// newline positions (including a possible empty trailing segment).
    private static func mapLines(_ block: String, _ transform: (String) -> String) -> String {
        // Split keeping track of trailing newline so we don't add/lose one.
        let hasTrailingNewline = block.hasSuffix("\n")
        var pieces = block.components(separatedBy: "\n")
        if hasTrailingNewline { pieces.removeLast() } // the empty piece after final \n
        let mapped = pieces.map(transform).joined(separator: "\n")
        return hasTrailingNewline ? mapped + "\n" : mapped
    }
}
