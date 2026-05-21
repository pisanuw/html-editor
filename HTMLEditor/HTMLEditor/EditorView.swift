import SwiftUI
import AppKit

/// The code editor for one document. Recreated per active tab (keyed by the
/// document id in `ContentView`), so its `NSTextView` always reflects the active
/// document. Restores the document's saved selection on appear and records it as
/// the caret moves, so switching tabs keeps each document's cursor position.
struct EditorView: NSViewRepresentable {
    @ObservedObject var document: DocumentModel
    @EnvironmentObject var textViewStore: TextViewStore

    func makeCoordinator() -> Coordinator { Coordinator(self) }

    func makeNSView(context: Context) -> NSScrollView {
        let textView = makeTextView(coordinator: context.coordinator)
        textView.string = document.htmlText
        applyHighlight(to: textView)
        textViewStore.textView = textView

        let scrollView = NSScrollView()
        scrollView.documentView = textView
        scrollView.hasVerticalScroller = true
        scrollView.hasHorizontalScroller = false
        scrollView.autohidesScrollers = true
        scrollView.borderType = .noBorder

        // Line-number gutter.
        let ruler = LineNumberRulerView(textView: textView)
        scrollView.verticalRulerView = ruler
        scrollView.hasVerticalRuler = true
        scrollView.rulersVisible = true
        context.coordinator.ruler = ruler

        // Redraw line numbers while scrolling.
        scrollView.contentView.postsBoundsChangedNotifications = true
        context.coordinator.observeScrolling(of: scrollView.contentView)

        // Restore this document's last selection.
        if let saved = document.savedSelection {
            let clamped = clamp(saved, to: textView.string)
            textView.setSelectedRange(clamped)
            DispatchQueue.main.async { textView.scrollRangeToVisible(clamped) }
        }

        return scrollView
    }

    func updateNSView(_ scrollView: NSScrollView, context: Context) {
        guard let textView = scrollView.documentView as? NSTextView else { return }
        textViewStore.textView = textView
        guard !context.coordinator.isEditing, textView.string != document.htmlText else { return }
        let sel = textView.selectedRange()
        textView.string = document.htmlText
        applyHighlight(to: textView)
        textView.setSelectedRange(clamp(sel, to: document.htmlText))
        context.coordinator.ruler?.refresh()
    }

    // MARK: - Helpers

    private func clamp(_ range: NSRange, to text: String) -> NSRange {
        let length = (text as NSString).length
        let location = min(range.location, length)
        return NSRange(location: location, length: min(range.length, length - location))
    }

    private func makeTextView(coordinator: Coordinator) -> NSTextView {
        let textView = NSTextView()
        textView.isRichText = false
        textView.isEditable = true
        textView.isSelectable = true
        textView.allowsUndo = true
        textView.isAutomaticQuoteSubstitutionEnabled = false
        textView.isAutomaticDashSubstitutionEnabled = false
        textView.isAutomaticSpellingCorrectionEnabled = false
        textView.isGrammarCheckingEnabled = false
        textView.font = .monospacedSystemFont(ofSize: 13, weight: .regular)
        textView.textContainerInset = NSSize(width: 6, height: 8)
        textView.textContainer?.widthTracksTextView = true
        textView.delegate = coordinator
        return textView
    }

    private func applyHighlight(to textView: NSTextView) {
        guard let storage = textView.textStorage else { return }
        HTMLSyntaxHighlighter.highlight(storage)
    }

    // MARK: - Coordinator

    class Coordinator: NSObject, NSTextViewDelegate {
        var parent: EditorView
        var isEditing = false
        var isAutoClosing = false
        weak var ruler: LineNumberRulerView?

        init(_ parent: EditorView) { self.parent = parent }

        func observeScrolling(of clipView: NSClipView) {
            NotificationCenter.default.addObserver(
                forName: NSView.boundsDidChangeNotification,
                object: clipView,
                queue: .main) { [weak self] _ in
                self?.ruler?.refresh()
            }
        }

        func textDidChange(_ notification: Notification) {
            guard !isEditing, let tv = notification.object as? NSTextView else { return }
            isEditing = true
            if let storage = tv.textStorage {
                let sel = tv.selectedRange()
                HTMLSyntaxHighlighter.highlight(storage)
                tv.setSelectedRange(sel)
            }
            let newText = tv.string
            isEditing = false
            ruler?.refresh()
            // Defer @Published update to avoid publishing during a SwiftUI update.
            DispatchQueue.main.async { [weak self] in
                self?.parent.document.htmlText = newText
            }
        }

        func textViewDidChangeSelection(_ notification: Notification) {
            guard let tv = notification.object as? NSTextView else { return }
            let selection = tv.selectedRange()
            let str = tv.string
            parent.document.savedSelection = selection
            updateMatchHighlight(tv)
            DispatchQueue.main.async { [weak self] in
                self?.parent.document.updateCursor(in: str, at: selection.location)
            }
        }

        /// Highlight the matching tag-name pair or bracket pair around the caret.
        /// Uses temporary attributes, which are display-only and do not disturb
        /// the syntax-highlight colors stored on the text.
        private func updateMatchHighlight(_ tv: NSTextView) {
            guard let lm = tv.layoutManager else { return }
            let full = NSRange(location: 0, length: (tv.string as NSString).length)
            lm.removeTemporaryAttribute(.backgroundColor, forCharacterRange: full)

            let caret = tv.selectedRange()
            guard caret.length == 0 else { return }
            let color = NSColor.systemTeal.withAlphaComponent(0.30)

            if let (a, b) = TagEditing.matchingTagNameRanges(in: tv.string, caret: caret.location) {
                lm.addTemporaryAttribute(.backgroundColor, value: color, forCharacterRange: a)
                lm.addTemporaryAttribute(.backgroundColor, value: color, forCharacterRange: b)
            } else if let (open, close) = CodeStructure.matchingBracket(in: tv.string, caret: caret.location) {
                lm.addTemporaryAttribute(.backgroundColor, value: color, forCharacterRange: open)
                lm.addTemporaryAttribute(.backgroundColor, value: color, forCharacterRange: close)
            }
        }

        /// Auto-close a tag when the user types the `>` that completes it.
        func textView(_ textView: NSTextView,
                      shouldChangeTextIn affectedCharRange: NSRange,
                      replacementString: String?) -> Bool {
            guard !isAutoClosing, replacementString == ">" else { return true }

            let ns = textView.string as NSString
            let afterInsert = ns.replacingCharacters(in: affectedCharRange, with: ">")
            let caretAfter = affectedCharRange.location + 1
            guard let result = TagEditing.autoClose(in: afterInsert, caretAfterBracket: caretAfter) else { return true }

            isAutoClosing = true
            defer { isAutoClosing = false }
            let insertion = ">" + result.closing
            if textView.shouldChangeText(in: affectedCharRange, replacementString: insertion) {
                textView.replaceCharacters(in: affectedCharRange, with: insertion)
                textView.didChangeText()
                textView.setSelectedRange(NSRange(location: affectedCharRange.location + 1, length: 0))
            }
            return false
        }

        /// HTML tag / attribute completions for the current caret context.
        func textView(_ textView: NSTextView,
                      completions words: [String],
                      forPartialWordRange charRange: NSRange,
                      indexOfSelectedItem index: UnsafeMutablePointer<Int>?) -> [String] {
            switch HTMLCompletion.context(in: textView.string, caret: textView.selectedRange().location) {
            case .tagName(let prefix, _):
                let hits = HTMLCompletion.tagCompletions(prefix: prefix)
                return hits.isEmpty ? words : hits
            case .attributeName(let prefix, _):
                let hits = HTMLCompletion.attributeCompletions(prefix: prefix)
                return hits.isEmpty ? words : hits
            case .none:
                return words
            }
        }

        // Intercept Tab / Shift-Tab / Return for smart indentation.
        func textView(_ textView: NSTextView, doCommandBy commandSelector: Selector) -> Bool {
            let selection = textView.selectedRange()
            switch commandSelector {
            case #selector(NSResponder.insertTab(_:)):
                apply(TextEditingOps.insertTab(in: textView.string, selection: selection), to: textView)
                return true
            case #selector(NSResponder.insertBacktab(_:)):
                apply(TextEditingOps.outdentLines(in: textView.string, selection: selection), to: textView)
                return true
            case #selector(NSResponder.insertNewline(_:)):
                apply(TextEditingOps.insertNewline(in: textView.string, selection: selection), to: textView)
                return true
            default:
                return false
            }
        }

        private func apply(_ result: TextEditingOps.EditResult, to tv: NSTextView) {
            let whole = NSRange(location: 0, length: (tv.string as NSString).length)
            guard tv.shouldChangeText(in: whole, replacementString: result.text) else { return }
            tv.replaceCharacters(in: whole, with: result.text)
            tv.didChangeText()
            tv.setSelectedRange(result.selection)
        }
    }
}
