import AppKit

/// A gutter that draws 1-based line numbers alongside an `NSTextView`.
/// Numbers are aligned to each logical line's first line-fragment, so wrapped
/// lines share a single number (standard editor behavior).
final class LineNumberRulerView: NSRulerView {

    private weak var managedTextView: NSTextView?
    weak var foldingController: FoldingController?
    private var foldControls: [(line0: Int, rect: NSRect, folded: Bool)] = []

    init(textView: NSTextView) {
        self.managedTextView = textView
        super.init(scrollView: textView.enclosingScrollView, orientation: .verticalRuler)
        clientView = textView
        ruleThickness = 44
    }

    required init(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    func refresh() {
        needsDisplay = true
    }

    private var rulerFont: NSFont {
        NSFont.monospacedDigitSystemFont(ofSize: 10, weight: .regular)
    }

    override func drawHashMarksAndLabels(in rect: NSRect) {
        guard let textView = managedTextView,
              let layoutManager = textView.layoutManager,
              let container = textView.textContainer else { return }

        // Background + trailing separator.
        NSColor.textBackgroundColor.setFill()
        bounds.fill()
        NSColor.separatorColor.setStroke()
        let separator = NSBezierPath()
        separator.move(to: NSPoint(x: bounds.maxX - 0.5, y: bounds.minY))
        separator.line(to: NSPoint(x: bounds.maxX - 0.5, y: bounds.maxY))
        separator.lineWidth = 1
        separator.stroke()

        let content = textView.string as NSString
        let inset = textView.textContainerInset.height
        // Offset between the text view's coordinate space and the ruler's.
        let yOffset = convert(NSPoint.zero, from: textView).y

        foldControls.removeAll()
        let foldableLines = foldingController?.foldableLines() ?? []

        let attributes: [NSAttributedString.Key: Any] = [
            .font: rulerFont,
            .foregroundColor: NSColor.secondaryLabelColor
        ]

        let visibleRect = textView.visibleRect
        let visibleGlyphRange = layoutManager.glyphRange(forBoundingRect: visibleRect, in: container)
        let firstVisibleCharIndex = layoutManager.characterIndexForGlyph(at: visibleGlyphRange.location)

        // Count newlines before the first visible character to seed the number.
        var lineNumber = 1
        var scan = 0
        while scan < firstVisibleCharIndex {
            if content.character(at: scan) == 10 { lineNumber += 1 }
            scan += 1
        }

        var glyphIndex = visibleGlyphRange.location
        let endGlyph = NSMaxRange(visibleGlyphRange)

        while glyphIndex < endGlyph {
            let charIndex = layoutManager.characterIndexForGlyph(at: glyphIndex)
            let lineCharRange = content.lineRange(for: NSRange(location: charIndex, length: 0))
            let lineGlyphRange = layoutManager.glyphRange(forCharacterRange: lineCharRange,
                                                          actualCharacterRange: nil)

            var effectiveRange = NSRange()
            let fragmentRect = layoutManager.lineFragmentRect(forGlyphAt: lineGlyphRange.location,
                                                              effectiveRange: &effectiveRange)
            let lineY = fragmentRect.minY + yOffset + inset
            draw(number: lineNumber,
                 atY: lineY,
                 height: fragmentRect.height,
                 attributes: attributes)

            // Fold triangle for foldable lines (0-based line index).
            let line0 = lineNumber - 1
            if foldableLines.contains(line0) {
                let folded = foldingController?.isFolded(line: line0) ?? false
                let rect = drawFoldTriangle(atY: lineY, height: fragmentRect.height, folded: folded)
                foldControls.append((line0: line0, rect: rect, folded: folded))
            }

            lineNumber += 1
            if lineGlyphRange.length == 0 {
                glyphIndex += 1 // safety against zero-length progress
            } else {
                glyphIndex = NSMaxRange(lineGlyphRange)
            }
        }

        // Final empty line when the document is empty or ends in a newline.
        let endsWithNewline = content.length > 0 && content.character(at: content.length - 1) == 10
        if content.length == 0 || endsWithNewline {
            let extra = layoutManager.extraLineFragmentRect
            if extra.height > 0 {
                draw(number: lineNumber,
                     atY: extra.minY + yOffset + inset,
                     height: extra.height,
                     attributes: attributes)
            }
        }
    }

    private func draw(number: Int, atY y: CGFloat, height: CGFloat,
                      attributes: [NSAttributedString.Key: Any]) {
        let label = "\(number)" as NSString
        let size = label.size(withAttributes: attributes)
        let drawRect = NSRect(x: ruleThickness - size.width - 6,
                              y: y + (height - size.height) / 2,
                              width: size.width,
                              height: size.height)
        label.draw(in: drawRect, withAttributes: attributes)
    }

    /// Draw a fold disclosure triangle near the left edge and return its
    /// (slightly padded) clickable rect.
    @discardableResult
    private func drawFoldTriangle(atY y: CGFloat, height: CGFloat, folded: Bool) -> NSRect {
        let box = NSRect(x: 3, y: y + (height - 9) / 2, width: 9, height: 9)
        let path = NSBezierPath()
        if folded {
            // ▶ pointing right
            path.move(to: NSPoint(x: box.minX + 1, y: box.minY))
            path.line(to: NSPoint(x: box.maxX - 1, y: box.midY))
            path.line(to: NSPoint(x: box.minX + 1, y: box.maxY))
        } else {
            // ▼ pointing down
            path.move(to: NSPoint(x: box.minX, y: box.maxY - 1))
            path.line(to: NSPoint(x: box.maxX, y: box.maxY - 1))
            path.line(to: NSPoint(x: box.midX, y: box.minY + 1))
        }
        path.close()
        NSColor.secondaryLabelColor.setFill()
        path.fill()
        return box.insetBy(dx: -3, dy: -3)
    }

    override func mouseDown(with event: NSEvent) {
        let point = convert(event.locationInWindow, from: nil)
        if let control = foldControls.first(where: { $0.rect.contains(point) }) {
            foldingController?.toggle(line: control.line0)
            return
        }
        super.mouseDown(with: event)
    }
}
