import Foundation

/// A lightweight, dependency-free HTML pretty-printer.
///
/// It re-flows markup so each tag and text node sits on its own line, indented
/// by nesting depth. It is deliberately simple (no full DOM): it understands
/// void elements, self-closing tags, comments, the doctype, and raw-content
/// elements whose interior must be preserved (`pre`, `textarea`) or kept intact
/// (`script`, `style`). Malformed input is reflowed on a best-effort basis
/// rather than rejected.
enum HTMLFormatter {

    private static let voidTags: Set<String> = [
        "area", "base", "br", "col", "embed", "hr", "img", "input",
        "link", "meta", "param", "source", "track", "wbr"
    ]
    /// Raw elements whose interior whitespace is significant and must be copied
    /// verbatim.
    private static let verbatimTags: Set<String> = ["pre", "textarea"]
    /// Raw elements whose interior is code we keep but re-indent as a block.
    private static let codeTags: Set<String> = ["script", "style"]

    static func prettify(_ html: String, indentWidth: Int = 2) -> String {
        let indentUnit = String(repeating: " ", count: max(1, indentWidth))
        let chars = Array(html)
        let n = chars.count

        var lines: [String] = []
        var depth = 0
        var i = 0

        func pad(_ d: Int) -> String { String(repeating: indentUnit, count: max(0, d)) }

        func emit(_ content: String, at d: Int) {
            let trimmed = content.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !trimmed.isEmpty else { return }
            lines.append(pad(d) + trimmed)
        }

        while i < n {
            if chars[i] == "<" {
                // Comment.
                if matchesCI(chars, i, "<!--") {
                    let end = indexAfter(chars, marker: "-->", from: i + 4)
                    let comment = String(chars[i..<end])
                    emitMultiline(comment, at: depth, pad: pad, into: &lines)
                    i = end
                    continue
                }
                // Doctype or other declaration / processing instruction.
                if i + 1 < n, chars[i + 1] == "!" || chars[i + 1] == "?" {
                    let end = indexAfterChar(chars, ">", from: i)
                    emit(String(chars[i..<end]), at: depth)
                    i = end
                    continue
                }
                // A tag. Read to the matching '>' respecting quoted attributes.
                let tagEnd = endOfTag(chars, from: i)
                let tag = String(chars[i..<tagEnd])
                let name = tagName(tag)
                let isClosing = tag.hasPrefix("</")
                let isSelfClosing = tag.hasSuffix("/>")
                    || (name.map(voidTags.contains) ?? false)

                if isClosing {
                    depth = max(0, depth - 1)
                    emit(tag, at: depth)
                    i = tagEnd
                    continue
                }

                // Raw-content elements: copy/keep their interior, then advance
                // past the matching close tag.
                if let name, verbatimTags.contains(name) || codeTags.contains(name) {
                    if let closeStart = indexOfClose(chars, name: name, from: tagEnd) {
                        let inner = String(chars[tagEnd..<closeStart])
                        let closeEnd = indexAfterChar(chars, ">", from: closeStart)
                        let closeTag = String(chars[closeStart..<closeEnd])

                        if verbatimTags.contains(name) {
                            // Keep open tag + inner + close tag as one verbatim
                            // unit so significant whitespace is untouched.
                            lines.append(pad(depth) + tag + inner + closeTag)
                        } else {
                            emit(tag, at: depth)
                            reindentCode(inner, at: depth + 1, pad: pad, into: &lines)
                            emit(closeTag, at: depth)
                        }
                        i = closeEnd
                        continue
                    }
                    // No matching close: treat as a normal opening tag.
                }

                emit(tag, at: depth)
                if !isSelfClosing { depth += 1 }
                i = tagEnd
            } else {
                // Text node up to the next '<'.
                let textEnd = indexOfChar(chars, "<", from: i) ?? n
                let text = String(chars[i..<textEnd])
                emit(collapseWhitespace(text), at: depth)
                i = textEnd
            }
        }

        return lines.joined(separator: "\n")
    }

    // MARK: - Scanning helpers

    /// Returns the index just past the closing `>` of the tag starting at
    /// `start`, skipping over quoted attribute values.
    private static func endOfTag(_ chars: [Character], from start: Int) -> Int {
        var i = start + 1
        var quote: Character?
        while i < chars.count {
            let c = chars[i]
            if let q = quote {
                if c == q { quote = nil }
            } else if c == "\"" || c == "'" {
                quote = c
            } else if c == ">" {
                return i + 1
            }
            i += 1
        }
        return chars.count
    }

    /// The lowercased element name of a tag string like `<div ...>` or `</div>`.
    private static func tagName(_ tag: String) -> String? {
        var chars = Array(tag)
        guard chars.first == "<" else { return nil }
        chars.removeFirst()
        if chars.first == "/" { chars.removeFirst() }
        var name = ""
        for c in chars {
            if c.isLetter || c.isNumber || c == "-" { name.append(c) } else { break }
        }
        return name.isEmpty ? nil : name.lowercased()
    }

    /// Index of the `<` that begins `</name>` at or after `from`, or nil.
    private static func indexOfClose(_ chars: [Character], name: String, from: Int) -> Int? {
        let needle = "</" + name
        var i = from
        while i < chars.count {
            if chars[i] == "<", matchesCI(chars, i, needle) {
                // Ensure the char after the name is a delimiter, not e.g. </scriptx>.
                let after = i + needle.count
                if after >= chars.count { return i }
                let c = chars[after]
                if c == ">" || c.isWhitespace || c == "/" { return i }
            }
            i += 1
        }
        return nil
    }

    private static func indexOfChar(_ chars: [Character], _ target: Character, from: Int) -> Int? {
        var i = from
        while i < chars.count {
            if chars[i] == target { return i }
            i += 1
        }
        return nil
    }

    private static func indexAfterChar(_ chars: [Character], _ target: Character, from: Int) -> Int {
        if let idx = indexOfChar(chars, target, from: from) { return idx + 1 }
        return chars.count
    }

    /// Index just past `marker` searched from `from`, or end of input.
    private static func indexAfter(_ chars: [Character], marker: String, from: Int) -> Int {
        let m = Array(marker)
        var i = from
        while i + m.count <= chars.count {
            if Array(chars[i..<(i + m.count)]) == m { return i + m.count }
            i += 1
        }
        return chars.count
    }

    private static func matchesCI(_ chars: [Character], _ at: Int, _ s: String) -> Bool {
        let m = Array(s)
        guard at + m.count <= chars.count else { return false }
        for k in 0..<m.count where chars[at + k].lowercased() != m[k].lowercased() {
            return false
        }
        return true
    }

    private static func collapseWhitespace(_ s: String) -> String {
        let parts = s.split(whereSeparator: { $0.isWhitespace })
        return parts.joined(separator: " ")
    }

    /// Emit a possibly multi-line block (e.g. a comment), indenting the first
    /// line and leaving interior lines as authored.
    private static func emitMultiline(_ block: String, at depth: Int,
                                      pad: (Int) -> String, into lines: inout [String]) {
        let trimmed = block.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }
        lines.append(pad(depth) + trimmed)
    }

    /// Re-indent the interior of a `<script>`/`<style>` block: trim surrounding
    /// blank lines, strip common leading indentation, then indent at `depth`.
    private static func reindentCode(_ code: String, at depth: Int,
                                     pad: (Int) -> String, into lines: inout [String]) {
        var rawLines = code.components(separatedBy: "\n")
        while let first = rawLines.first, first.trimmingCharacters(in: .whitespaces).isEmpty {
            rawLines.removeFirst()
        }
        while let last = rawLines.last, last.trimmingCharacters(in: .whitespaces).isEmpty {
            rawLines.removeLast()
        }
        guard !rawLines.isEmpty else { return }

        let minIndent = rawLines
            .filter { !$0.trimmingCharacters(in: .whitespaces).isEmpty }
            .map { $0.prefix { $0 == " " || $0 == "\t" }.count }
            .min() ?? 0

        for line in rawLines {
            if line.trimmingCharacters(in: .whitespaces).isEmpty {
                lines.append("")
            } else {
                lines.append(pad(depth) + String(line.dropFirst(minIndent)))
            }
        }
    }
}
