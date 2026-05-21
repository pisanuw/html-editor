import AppKit

// Holds a weak reference to the live NSTextView so toolbar actions can
// insert/wrap text at the current cursor position.
class TextViewStore: ObservableObject {
    weak var textView: NSTextView?

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

    private func replace(range: NSRange, with string: String, in tv: NSTextView) {
        guard tv.shouldChangeText(in: range, replacementString: string) else { return }
        tv.replaceCharacters(in: range, with: string)
        tv.didChangeText()
    }
}
