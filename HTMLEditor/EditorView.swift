import SwiftUI
import AppKit

struct EditorView: NSViewRepresentable {
    @Binding var text: String
    @EnvironmentObject var document: DocumentModel
    @EnvironmentObject var textViewStore: TextViewStore

    func makeCoordinator() -> Coordinator { Coordinator(self) }

    func makeNSView(context: Context) -> NSScrollView {
        let textView = makeTextView(coordinator: context.coordinator)
        applyHighlight(to: textView, string: text)
        textViewStore.textView = textView

        let scrollView = NSScrollView()
        scrollView.documentView = textView
        scrollView.hasVerticalScroller = true
        scrollView.hasHorizontalScroller = false
        scrollView.autohidesScrollers = true
        scrollView.borderType = .noBorder
        return scrollView
    }

    func updateNSView(_ scrollView: NSScrollView, context: Context) {
        guard let textView = scrollView.documentView as? NSTextView else { return }
        textViewStore.textView = textView
        guard !context.coordinator.isEditing, textView.string != text else { return }
        let sel = textView.selectedRange()
        textView.string = text
        applyHighlight(to: textView, string: text)
        let clampedSel = NSRange(
            location: min(sel.location, text.utf16.count),
            length: 0
        )
        textView.setSelectedRange(clampedSel)
    }

    // MARK: - Helpers

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
        textView.string = text
        return textView
    }

    private func applyHighlight(to textView: NSTextView, string: String) {
        guard let storage = textView.textStorage else { return }
        HTMLSyntaxHighlighter.highlight(storage)
    }

    // MARK: - Coordinator

    class Coordinator: NSObject, NSTextViewDelegate {
        var parent: EditorView
        var isEditing = false

        init(_ parent: EditorView) { self.parent = parent }

        func textDidChange(_ notification: Notification) {
            guard !isEditing, let tv = notification.object as? NSTextView else { return }
            isEditing = true
            parent.text = tv.string
            if let storage = tv.textStorage {
                let sel = tv.selectedRange()
                HTMLSyntaxHighlighter.highlight(storage)
                tv.setSelectedRange(sel)
            }
            isEditing = false
        }

        func textViewDidChangeSelection(_ notification: Notification) {
            guard let tv = notification.object as? NSTextView else { return }
            let loc = tv.selectedRange().location
            parent.document.updateCursor(in: tv.string, at: loc)
        }
    }
}
