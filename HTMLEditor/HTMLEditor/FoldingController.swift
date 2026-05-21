import AppKit

/// Implements code folding by suppressing the glyphs (and zeroing the control
/// characters) of folded character ranges via the layout manager delegate.
/// Which ranges to hide is decided by the pure, tested `FoldingModel`. One
/// controller is retained per editor (by `EditorCache`) so fold state and the
/// delegate connection survive tab switches.
final class FoldingController: NSObject, NSLayoutManagerDelegate {
    weak var textView: NSTextView?
    private(set) var foldedLines: Set<Int> = []
    private var hiddenRanges: [NSRange] = []

    private var text: String { textView?.string ?? "" }

    func foldableLines() -> Set<Int> { FoldingModel.foldableToggleLines(in: text) }
    func isFolded(line: Int) -> Bool { foldedLines.contains(line) }

    func toggle(line: Int) {
        if foldedLines.contains(line) { foldedLines.remove(line) } else { foldedLines.insert(line) }
        recompute()
        relayout()
    }

    /// Recompute hidden ranges and drop folds whose region no longer exists
    /// (e.g. after the user edited a folded tag away).
    func recompute() {
        foldedLines = foldedLines.intersection(foldableLines())
        hiddenRanges = FoldingModel.hiddenRanges(in: text, foldedToggleLines: foldedLines)
    }

    private func relayout() {
        guard let lm = textView?.layoutManager, let container = textView?.textContainer else { return }
        let full = NSRange(location: 0, length: (text as NSString).length)
        lm.invalidateGlyphs(forCharacterRange: full, changeInLength: 0, actualCharacterRange: nil)
        lm.invalidateLayout(forCharacterRange: full, actualCharacterRange: nil)
        lm.ensureLayout(for: container)
        textView?.needsDisplay = true
        (textView?.enclosingScrollView?.verticalRulerView as? LineNumberRulerView)?.refresh()
    }

    private func isHidden(_ charIndex: Int) -> Bool {
        for r in hiddenRanges where charIndex >= r.location && charIndex < r.location + r.length {
            return true
        }
        return false
    }

    // MARK: - NSLayoutManagerDelegate

    func layoutManager(_ layoutManager: NSLayoutManager,
                       shouldGenerateGlyphs glyphs: UnsafePointer<CGGlyph>,
                       properties props: UnsafePointer<NSLayoutManager.GlyphProperty>,
                       characterIndexes charIndexes: UnsafePointer<Int>,
                       font aFont: NSFont,
                       forGlyphRange glyphRange: NSRange) -> Int {
        guard !hiddenRanges.isEmpty else { return 0 }
        let count = glyphRange.length
        var newProps = Array(UnsafeBufferPointer(start: props, count: count))
        var changed = false
        for i in 0..<count where isHidden(charIndexes[i]) {
            newProps[i] = .null
            changed = true
        }
        guard changed else { return 0 }
        newProps.withUnsafeBufferPointer { buffer in
            layoutManager.setGlyphs(glyphs,
                                    properties: buffer.baseAddress!,
                                    characterIndexes: charIndexes,
                                    font: aFont,
                                    forGlyphRange: glyphRange)
        }
        return count
    }

    func layoutManager(_ layoutManager: NSLayoutManager,
                       shouldUse action: NSLayoutManager.ControlCharacterAction,
                       forControlCharacterAt charIndex: Int) -> NSLayoutManager.ControlCharacterAction {
        isHidden(charIndex) ? .zeroAdvancement : action
    }
}
