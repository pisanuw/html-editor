import AppKit
import Combine

/// Holds a weak reference to the live `NSTextView` so toolbar actions, the find
/// bar, and document-wide transforms can read and mutate the editor text at the
/// current cursor position. All edits go through `shouldChangeText`/`didChangeText`
/// so they participate in undo and notify SwiftUI bindings.
class TextViewStore: ObservableObject {
    weak var textView: NSTextView?

    // MARK: - Reading state

    var currentText: String { textView?.string ?? "" }

    var currentSelectionText: String {
        guard let tv = textView else { return "" }
        return (tv.string as NSString).substring(with: tv.selectedRange())
    }

    // MARK: - Snippet insertion (toolbar)

    func wrapSelection(before: String, after: String, placeholder: String = "text") {
        guard let tv = textView else { return }
        let range = tv.selectedRange()
        let selected = (tv.string as NSString).substring(with: range)
        let replacement = before + (selected.isEmpty ? placeholder : selected) + after
        replace(range: range, with: replacement, in: tv)
    }

    func insertSnippet(_ snippet: String) {
        guard let tv = textView else { return }
        replace(range: tv.selectedRange(), with: snippet, in: tv)
    }

    // MARK: - Whole-document replacement (format / export-in-place)

    func replaceAll(with newText: String) {
        guard let tv = textView else { return }
        let whole = NSRange(location: 0, length: (tv.string as NSString).length)
        guard newText != tv.string else { return }
        replace(range: whole, with: newText, in: tv)
    }

    // MARK: - Selection

    func select(_ range: NSRange) {
        guard let tv = textView else { return }
        tv.setSelectedRange(range)
        tv.scrollRangeToVisible(range)
        tv.window?.makeFirstResponder(tv)
    }

    // MARK: - Find / Replace

    /// Total number of matches for `query` in the current text.
    func count(of query: String, options: FindOptions) -> Int {
        FindEngine.matches(in: currentText, query: query, options: options).count
    }

    /// Find and select the next/previous match relative to the current
    /// selection, wrapping around. Returns the (1-based) match position and the
    /// total count, or `nil` if there are no matches.
    func find(_ query: String, options: FindOptions, forward: Bool) -> (current: Int, total: Int)? {
        guard let tv = textView else { return nil }
        let ranges = FindEngine.matches(in: tv.string, query: query, options: options)
        guard !ranges.isEmpty else { return nil }

        let caret = tv.selectedRange()
        let index: Int
        if let existing = ranges.firstIndex(where: { NSEqualRanges($0, caret) }) {
            index = FindEngine.step(from: existing, total: ranges.count, forward: forward) ?? 0
        } else if forward {
            index = FindEngine.firstMatchIndex(in: ranges, atOrAfter: caret.location) ?? 0
        } else {
            index = ranges.lastIndex(where: { $0.location < caret.location }) ?? (ranges.count - 1)
        }

        select(ranges[index])
        return (index + 1, ranges.count)
    }

    /// Replace the current selection if it is a match, then advance to the next
    /// match. Returns the new (current, total) position after advancing.
    @discardableResult
    func replaceCurrentThenFind(_ query: String,
                                with replacement: String,
                                options: FindOptions) -> (current: Int, total: Int)? {
        guard let tv = textView else { return nil }
        let selection = tv.selectedRange()
        if selection.length > 0 {
            let selectedText = (tv.string as NSString).substring(with: selection)
            let (expanded, replacedCount) = FindEngine.replaceAll(
                in: selectedText, query: query, replacement: replacement, options: options)
            if replacedCount > 0 {
                replace(range: selection, with: expanded, in: tv)
                tv.setSelectedRange(NSRange(location: selection.location, length: 0))
            }
        }
        return find(query, options: options, forward: true)
    }

    /// Replace every match in the document. Returns the number of replacements.
    @discardableResult
    func replaceAll(_ query: String,
                    with replacement: String,
                    options: FindOptions) -> Int {
        guard let tv = textView else { return 0 }
        let (newText, count) = FindEngine.replaceAll(
            in: tv.string, query: query, replacement: replacement, options: options)
        guard count > 0 else { return 0 }
        let whole = NSRange(location: 0, length: (tv.string as NSString).length)
        replace(range: whole, with: newText, in: tv)
        return count
    }

    // MARK: - Private

    private func replace(range: NSRange, with string: String, in tv: NSTextView) {
        guard tv.shouldChangeText(in: range, replacementString: string) else { return }
        tv.replaceCharacters(in: range, with: string)
        tv.didChangeText()
    }
}
