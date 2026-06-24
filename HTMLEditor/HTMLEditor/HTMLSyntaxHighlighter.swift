import AppKit

/// Applies syntax coloring to an `NSTextStorage`. The actual classification is
/// done by the pure, unit-tested ``SyntaxTokenizer`` (which understands HTML
/// plus embedded CSS and JavaScript); this type only maps the resulting tokens
/// onto text attributes using the dark/light-aware ``EditorTheme``.
///
/// After token-based coloring, CSS color literals (hex, rgb, hsl) receive a
/// thick colored underline so the actual color is visible at a glance.
enum HTMLSyntaxHighlighter {

    static func highlight(_ storage: NSTextStorage) {
        let str = storage.string
        let full = NSRange(location: 0, length: (str as NSString).length)

        storage.beginEditing()

        // Reset every character to the default appearance first.
        storage.addAttribute(.font, value: EditorTheme.font, range: full)
        storage.addAttribute(.foregroundColor, value: EditorTheme.foreground, range: full)

        // Remove any previous color-swatch underlines.
        storage.removeAttribute(.underlineStyle, range: full)
        storage.removeAttribute(.underlineColor, range: full)

        // Token-based coloring.
        for token in SyntaxTokenizer.tokenize(str) {
            storage.addAttribute(.foregroundColor,
                                 value: EditorTheme.color(for: token.type),
                                 range: token.range)
        }

        // CSS color swatches — thick underline in the actual color.
        applyColorSwatches(to: storage, in: str)

        storage.endEditing()
    }

    // MARK: - CSS color swatches

    private static func applyColorSwatches(to storage: NSTextStorage, in str: String) {
        let ns = str as NSString
        let len = ns.length
        var i = 0
        while i < len {
            // Hex color: # followed by 3, 4, 6, or 8 hex digits.
            if ns.character(at: i) == 35 /* # */ {
                let start = i
                i += 1
                var hexBuf = ""
                while i < len && hexBuf.count < 8 {
                    let c = ns.character(at: i)
                    guard isHex(c) else { break }
                    hexBuf.unicodeScalars.append(Unicode.Scalar(c)!)
                    i += 1
                }
                if hexBuf.count == 3 || hexBuf.count == 4
                    || hexBuf.count == 6 || hexBuf.count == 8,
                   let color = NSColor(hexString: hexBuf) {
                    let range = NSRange(location: start, length: 1 + hexBuf.count)
                    storage.addAttribute(.underlineStyle,
                                         value: NSUnderlineStyle.thick.rawValue,
                                         range: range)
                    storage.addAttribute(.underlineColor, value: color, range: range)
                }
                continue
            }

            // rgb( / rgba( / hsl( / hsla(
            if ns.character(at: i) == 114 /* r */ || ns.character(at: i) == 104 /* h */ {
                if let (range, color) = matchFunctionalColor(ns, at: i, limit: len) {
                    storage.addAttribute(.underlineStyle,
                                         value: NSUnderlineStyle.thick.rawValue,
                                         range: range)
                    storage.addAttribute(.underlineColor, value: color, range: range)
                    i = NSMaxRange(range)
                    continue
                }
            }

            i += 1
        }
    }

    private static func isHex(_ c: unichar) -> Bool {
        (c >= 48 && c <= 57) || (c >= 65 && c <= 70) || (c >= 97 && c <= 102)
    }

    /// Match rgb(r,g,b), rgba(r,g,b,a), hsl(h,s%,l%), hsla(...) at position i.
    /// Returns the full matched NSRange and parsed NSColor, or nil if no match.
    private static func matchFunctionalColor(_ ns: NSString, at start: Int, limit: Int)
            -> (NSRange, NSColor)? {
        // Quick prefix check.
        let prefixes = ["rgba(", "rgb(", "hsla(", "hsl("]
        var matched = ""
        for p in prefixes {
            let end = start + p.count
            guard end <= limit else { continue }
            let candidate = ns.substring(with: NSRange(location: start, length: p.count))
                              .lowercased()
            if candidate == p { matched = p; break }
        }
        guard !matched.isEmpty else { return nil }

        // Scan to closing ')'.
        var j = start + matched.count
        while j < limit && ns.character(at: j) != 41 /* ) */ { j += 1 }
        guard j < limit else { return nil }
        j += 1 // include ')'

        let range = NSRange(location: start, length: j - start)
        let raw = ns.substring(with: range)
        guard let color = NSColor(cssFunction: raw) else { return nil }
        return (range, color)
    }
}

// MARK: - NSColor parsing helpers

private extension NSColor {
    convenience init?(hexString hex: String) {
        var s = hex
        if s.count == 3 || s.count == 4 {
            s = s.map { "\($0)\($0)" }.joined()
        }
        guard s.count == 6 || s.count == 8 else { return nil }
        var value: UInt64 = 0
        guard Scanner(string: s).scanHexInt64(&value) else { return nil }
        if s.count == 6 {
            self.init(srgbRed: CGFloat((value >> 16) & 0xFF) / 255,
                      green: CGFloat((value >> 8) & 0xFF) / 255,
                      blue: CGFloat( value & 0xFF) / 255,
                      alpha: 1)
        } else {
            self.init(srgbRed: CGFloat((value >> 24) & 0xFF) / 255,
                      green: CGFloat((value >> 16) & 0xFF) / 255,
                      blue: CGFloat((value >> 8) & 0xFF) / 255,
                      alpha: CGFloat( value & 0xFF) / 255)
        }
    }

    convenience init?(cssFunction raw: String) {
        // Normalize: lowercase, remove spaces around parens/commas.
        let s = raw.lowercased()
            .replacingOccurrences(of: " ", with: "")
        // Extract inner content between '(' and ')'.
        guard let open = s.firstIndex(of: "("),
              let close = s.lastIndex(of: ")") else { return nil }
        let inner = String(s[s.index(after: open)..<close])
        let parts = inner.split(separator: ",").map { $0.trimmingCharacters(in: .whitespaces) }

        if s.hasPrefix("rgb") && (parts.count == 3 || parts.count == 4) {
            guard let r = Double(parts[0]), let g = Double(parts[1]), let b = Double(parts[2]) else { return nil }
            let a = parts.count == 4 ? (Double(parts[3]) ?? 1.0) : 1.0
            self.init(srgbRed: CGFloat(r / 255), green: CGFloat(g / 255), blue: CGFloat(b / 255), alpha: CGFloat(a))
        } else if s.hasPrefix("hsl") && (parts.count == 3 || parts.count == 4) {
            guard let h = Double(parts[0]),
                  let sv = Double(parts[1].replacingOccurrences(of: "%", with: "")),
                  let lv = Double(parts[2].replacingOccurrences(of: "%", with: "")) else { return nil }
            let a = parts.count == 4 ? (Double(parts[3].replacingOccurrences(of: "%", with: "")) ?? 100.0) / 100.0 : 1.0
            self.init(hue: CGFloat(h / 360), saturation: CGFloat(sv / 100),
                      brightness: CGFloat(lv / 100), alpha: CGFloat(a))
        } else {
            return nil
        }
    }
}
