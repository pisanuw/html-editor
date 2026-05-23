import SwiftUI
import AppKit

/// A narrow, read-only thumbnail of the document shown to the right of the
/// editor text area. Uses a 2pt font so the whole file is visible at once.
/// The viewport indicator rectangle shows which portion of the document is
/// currently visible in the main editor.
struct MinimapView: NSViewRepresentable {
    @ObservedObject var document: DocumentModel

    func makeCoordinator() -> Coordinator { Coordinator() }

    func makeNSView(context: Context) -> MinimapHostView {
        let host = MinimapHostView()
        host.textView.string = document.htmlText
        if let storage = host.textView.textStorage {
            HTMLSyntaxHighlighter.highlight(storage)
            overrideFont(storage)
        }
        context.coordinator.host = host
        return host
    }

    func updateNSView(_ host: MinimapHostView, context: Context) {
        guard host.textView.string != document.htmlText else { return }
        host.textView.string = document.htmlText
        if let storage = host.textView.textStorage {
            HTMLSyntaxHighlighter.highlight(storage)
            overrideFont(storage)
        }
    }

    private func overrideFont(_ storage: NSTextStorage) {
        let tiny = NSFont.monospacedSystemFont(ofSize: 2, weight: .regular)
        storage.addAttribute(.font, value: tiny,
                             range: NSRange(location: 0, length: storage.length))
    }

    class Coordinator {
        weak var host: MinimapHostView?
    }
}

/// NSView container holding the tiny read-only NSTextView and the translucent
/// viewport indicator overlay.
final class MinimapHostView: NSView {
    let scrollView = NSScrollView()
    let textView   = NSTextView()

    override init(frame: NSRect) {
        super.init(frame: frame)
        setup()
    }
    required init?(coder: NSCoder) { fatalError() }

    private func setup() {
        textView.isEditable = false
        textView.isSelectable = false
        textView.isRichText = true
        textView.backgroundColor = NSColor.textBackgroundColor
        textView.textContainerInset = NSSize(width: 2, height: 4)
        textView.textContainer?.widthTracksTextView = true
        textView.isHorizontallyResizable = false

        scrollView.documentView = textView
        scrollView.hasVerticalScroller = false
        scrollView.hasHorizontalScroller = false
        scrollView.borderType = .noBorder
        scrollView.autoresizingMask = [.width, .height]
        scrollView.frame = bounds
        addSubview(scrollView)
    }

    override func resizeSubviews(withOldSize oldSize: NSSize) {
        super.resizeSubviews(withOldSize: oldSize)
        scrollView.frame = bounds
    }
}
