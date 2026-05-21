import SwiftUI
import AppKit

/// The code editor for one document. The underlying `NSScrollView`/`NSTextView`
/// is cached per document id (see `EditorCache`), so switching tabs reuses the
/// same text view — preserving its undo stack and selection — instead of
/// rebuilding it. Font, indent width, and colors follow the app settings.
struct EditorView: NSViewRepresentable {
    @ObservedObject var document: DocumentModel
    @EnvironmentObject var textViewStore: TextViewStore
    @EnvironmentObject var settingsStore: AppSettingsStore
    @EnvironmentObject var editorCache: EditorCache

    func makeCoordinator() -> Coordinator { Coordinator(self) }

    func makeNSView(context: Context) -> NSScrollView {
        context.coordinator.parent = self

        // Reuse a cached editor for this document if we have one.
        if let cached = editorCache.scrollView(for: document.id),
           let textView = cached.documentView as? NSTextView {
            reconfigure(cached, textView: textView, coordinator: context.coordinator)
            return cached
        }

        let scrollView = buildScrollView(coordinator: context.coordinator)
        editorCache.store(scrollView, for: document.id)
        return scrollView
    }

    func updateNSView(_ scrollView: NSScrollView, context: Context) {
        context.coordinator.parent = self
        guard let textView = scrollView.documentView as? NSTextView else { return }
        textViewStore.textView = textView
        guard !context.coordinator.isEditing, textView.string != document.htmlText else { return }
        let sel = textView.selectedRange()
        textView.string = document.htmlText
        applyHighlight(to: textView)
        textView.setSelectedRange(clamp(sel, to: document.htmlText))
        context.coordinator.ruler?.refresh()
    }

    // MARK: - Building / reconfiguring

    private func buildScrollView(coordinator: Coordinator) -> NSScrollView {
        let textView = makeTextView(coordinator: coordinator)
        textView.string = document.htmlText
        applyHighlight(to: textView)
        textViewStore.textView = textView
        coordinator.textView = textView

        let scrollView = NSScrollView()
        scrollView.documentView = textView
        scrollView.hasVerticalScroller = true
        scrollView.hasHorizontalScroller = false
        scrollView.autohidesScrollers = true
        scrollView.borderType = .noBorder

        let ruler = LineNumberRulerView(textView: textView)
        scrollView.verticalRulerView = ruler
        scrollView.hasVerticalRuler = true
        scrollView.rulersVisible = true
        coordinator.ruler = ruler

        scrollView.contentView.postsBoundsChangedNotifications = true
        coordinator.observeScrolling(of: scrollView.contentView)

        if let saved = document.savedSelection {
            let clamped = clamp(saved, to: textView.string)
            textView.setSelectedRange(clamped)
            DispatchQueue.main.async { textView.scrollRangeToVisible(clamped) }
        }
        return scrollView
    }

    private func reconfigure(_ scrollView: NSScrollView, textView: NSTextView, coordinator: Coordinator) {
        textView.delegate = coordinator
        coordinator.textView = textView
        textViewStore.textView = textView
        if let ruler = scrollView.verticalRulerView as? LineNumberRulerView {
            coordinator.ruler = ruler
        }
        coordinator.observeScrolling(of: scrollView.contentView)
        coordinator.applySettings()

        // If the buffer diverged from the view while cached (e.g. external
        // reload), resync the text (this resets undo for that document only).
        if textView.string != document.htmlText {
            let sel = textView.selectedRange()
            textView.string = document.htmlText
            applyHighlight(to: textView)
            textView.setSelectedRange(clamp(sel, to: document.htmlText))
        }
        coordinator.ruler?.refresh()
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
        textView.font = .monospacedSystemFont(ofSize: CGFloat(settingsStore.settings.fontSize), weight: .regular)
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
        weak var textView: NSTextView?
        private var observers: [NSObjectProtocol] = []

        init(_ parent: EditorView) {
            self.parent = parent
            super.init()
            let token = NotificationCenter.default.addObserver(
                forName: .editorSettingsChanged, object: nil, queue: .main) { [weak self] _ in
                self?.applySettings()
            }
            observers.append(token)
        }

        deinit { observers.forEach { NotificationCenter.default.removeObserver($0) } }

        /// Apply the current font size and re-highlight with the active theme.
        func applySettings() {
            guard let tv = textView else { return }
            tv.font = .monospacedSystemFont(ofSize: CGFloat(parent.settingsStore.settings.fontSize), weight: .regular)
            if let storage = tv.textStorage {
                let sel = tv.selectedRange()
                HTMLSyntaxHighlighter.highlight(storage)
                tv.setSelectedRange(sel)
            }
            ruler?.refresh()
        }

        func observeScrolling(of clipView: NSClipView) {
            let token = NotificationCenter.default.addObserver(
                forName: NSView.boundsDidChangeNotification,
                object: clipView,
                queue: .main) { [weak self] _ in
                self?.ruler?.refresh()
            }
            observers.append(token)
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

        // Intercept Tab / Shift-Tab / Return for smart, localized indentation.
        func textView(_ textView: NSTextView, doCommandBy commandSelector: Selector) -> Bool {
            let selection = textView.selectedRange()
            let iw = parent.settingsStore.settings.sanitized.indentWidth
            switch commandSelector {
            case #selector(NSResponder.insertTab(_:)):
                applyLocal(TextEditingOps.tabEdit(in: textView.string, selection: selection, indentWidth: iw), to: textView)
                return true
            case #selector(NSResponder.insertBacktab(_:)):
                applyLocal(TextEditingOps.outdentEdit(in: textView.string, selection: selection, indentWidth: iw), to: textView)
                return true
            case #selector(NSResponder.insertNewline(_:)):
                applyLocal(TextEditingOps.newlineEdit(in: textView.string, selection: selection, indentWidth: iw), to: textView)
                return true
            default:
                return false
            }
        }

        /// Apply a localized edit (touches only the affected range, so undo is
        /// tighter and large documents aren't rewritten wholesale).
        private func applyLocal(_ edit: TextEditingOps.RangeEdit, to tv: NSTextView) {
            guard tv.shouldChangeText(in: edit.range, replacementString: edit.replacement) else { return }
            tv.replaceCharacters(in: edit.range, with: edit.replacement)
            tv.didChangeText()
            tv.setSelectedRange(edit.selection)
        }
    }
}
