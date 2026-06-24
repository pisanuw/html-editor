import Foundation

/// Converts a useful subset of HTML to Markdown. Pure and Foundation-only, so
/// the conversion is unit-tested. Aimed at the kind of clean markup this editor
/// produces rather than arbitrary web HTML; unknown tags pass their children
/// through.
enum HTMLToMarkdown {

    static func convert(_ html: String) -> String {
        var parser = Parser(Array(html))
        let nodes = parser.parseNodes(until: nil)
        return Renderer().renderBlocks(nodes)
            .replacingOccurrences(of: "\n\n\n", with: "\n\n")
            .trimmingCharacters(in: .whitespacesAndNewlines)
    }

    // MARK: - Model

    indirect enum Node {
        case text(String)
        case element(tag: String, attrs: [String: String], children: [Node])
    }

    static let voidTags: Set<String> = [
        "area", "base", "br", "col", "embed", "hr", "img", "input",
        "link", "meta", "param", "source", "track", "wbr"
    ]

    // MARK: - Parser

    struct Parser {
        private let chars: [Character]
        private var i = 0
        init(_ chars: [Character]) { self.chars = chars }

        mutating func parseNodes(until closeTag: String?) -> [Node] {
            var nodes: [Node] = []
            var text = ""
            func flush() { if !text.isEmpty { nodes.append(.text(text)); text = "" } }

            while i < chars.count {
                guard chars[i] == "<" else { text.append(chars[i]); i += 1; continue }

                if startsWith("<!--") { skip(past: "-->"); continue }
                if startsWith("<!") || startsWith("<?") { skip(past: ">"); continue }

                if startsWith("</") {
                    i += 2
                    let name = readName()
                    skip(past: ">")
                    flush()
                    if let close = closeTag, name.lowercased() == close.lowercased() { return nodes }
                    continue // stray/own close: stop our level for our own tag, ignore others
                }

                i += 1
                let name = readName()
                let (attrs, selfClose) = readAttributes()
                flush()
                if name.isEmpty { continue }
                if selfClose || voidTags.contains(name.lowercased()) {
                    nodes.append(.element(tag: name, attrs: attrs, children: []))
                } else {
                    let children = parseNodes(until: name)
                    nodes.append(.element(tag: name, attrs: attrs, children: children))
                }
            }
            flush()
            return nodes
        }

        private func startsWith(_ s: String) -> Bool {
            let p = Array(s)
            guard i + p.count <= chars.count else { return false }
            for k in 0..<p.count where chars[i + k] != p[k] { return false }
            return true
        }

        private mutating func skip(past token: String) {
            let p = Array(token)
            while i < chars.count {
                if i + p.count <= chars.count, Array(chars[i..<i + p.count]) == p {
                    i += p.count
                    return
                }
                i += 1
            }
        }

        private mutating func readName() -> String {
            var name = ""
            while i < chars.count {
                let c = chars[i]
                if c.isLetter || c.isNumber || c == "-" || c == "_" || c == ":" { name.append(c); i += 1 } else { break }
            }
            return name
        }

        private mutating func readAttributes() -> ([String: String], Bool) {
            var attrs: [String: String] = [:]
            var selfClose = false
            while i < chars.count {
                let c = chars[i]
                if c == ">" { i += 1; break }
                if c == "/" { selfClose = true; i += 1; continue }
                if c == " " || c == "\t" || c == "\n" || c == "\r" { i += 1; continue }

                let attrName = readName()
                if attrName.isEmpty { i += 1; continue } // unexpected char; skip
                var value = ""
                if i < chars.count, chars[i] == "=" {
                    i += 1
                    value = readAttributeValue()
                }
                attrs[attrName.lowercased()] = value
            }
            return (attrs, selfClose)
        }

        private mutating func readAttributeValue() -> String {
            guard i < chars.count else { return "" }
            if chars[i] == "\"" || chars[i] == "'" {
                let quote = chars[i]; i += 1
                var v = ""
                while i < chars.count, chars[i] != quote { v.append(chars[i]); i += 1 }
                if i < chars.count { i += 1 } // closing quote
                return v
            }
            var v = ""
            while i < chars.count, chars[i] != " ", chars[i] != ">", chars[i] != "/" { v.append(chars[i]); i += 1 }
            return v
        }
    }

    // MARK: - Renderer

    struct Renderer {
        private let blockTags: Set<String> = [
            "h1", "h2", "h3", "h4", "h5", "h6", "p", "div", "section", "article",
            "header", "footer", "main", "ul", "ol", "blockquote", "pre", "hr"
        ]

        func renderBlocks(_ nodes: [Node]) -> String {
            var blocks: [String] = []
            for node in nodes {
                switch node {
                case .text(let raw):
                    let s = collapse(decode(raw)).trimmingCharacters(in: .whitespaces)
                    if !s.isEmpty { blocks.append(s) }
                case .element(let tag, let attrs, let children):
                    let name = tag.lowercased()
                    if blockTags.contains(name) {
                        if let b = renderBlock(name, attrs, children), !b.isEmpty { blocks.append(b) }
                    } else {
                        let inline = renderInline([node])
                        if !inline.isEmpty { blocks.append(inline) }
                    }
                }
            }
            return blocks.joined(separator: "\n\n")
        }

        private func renderBlock(_ tag: String, _ attrs: [String: String], _ children: [Node]) -> String? {
            switch tag {
            case "h1", "h2", "h3", "h4", "h5", "h6":
                let level = Int(String(tag.dropFirst())) ?? 1
                return String(repeating: "#", count: level) + " " + renderInline(children).trimmingCharacters(in: .whitespaces)
            case "p":
                return renderInline(children).trimmingCharacters(in: .whitespaces)
            case "hr":
                return "---"
            case "pre":
                return "```\n" + plainText(children) + "\n```"
            case "blockquote":
                let inner = renderBlocks(children)
                return inner.split(separator: "\n", omittingEmptySubsequences: false)
                    .map { $0.isEmpty ? ">" : "> " + $0 }
                    .joined(separator: "\n")
            case "ul":
                return renderList(children, ordered: false, indent: 0)
            case "ol":
                return renderList(children, ordered: true, indent: 0)
            case "div", "section", "article", "header", "footer", "main":
                return renderBlocks(children)
            default:
                return renderInline(children)
            }
        }

        private func renderList(_ children: [Node], ordered: Bool, indent: Int) -> String {
            var lines: [String] = []
            var n = 1
            for node in children {
                guard case .element(let tag, _, let liChildren) = node, tag.lowercased() == "li" else { continue }
                var inlineNodes: [Node] = []
                var nested: [String] = []
                for ch in liChildren {
                    if case .element(let ct, _, let cc) = ch, ct.lowercased() == "ul" || ct.lowercased() == "ol" {
                        nested.append(renderList(cc, ordered: ct.lowercased() == "ol", indent: indent + 1))
                    } else {
                        inlineNodes.append(ch)
                    }
                }
                let pad = String(repeating: "  ", count: indent)
                let marker = ordered ? "\(n). " : "- "
                lines.append(pad + marker + renderInline(inlineNodes).trimmingCharacters(in: .whitespaces))
                lines.append(contentsOf: nested)
                n += 1
            }
            return lines.joined(separator: "\n")
        }

        private func renderInline(_ nodes: [Node]) -> String {
            var out = ""
            for node in nodes {
                switch node {
                case .text(let raw):
                    out += collapse(decode(raw))
                case .element(let tag, let attrs, let children):
                    out += renderInlineElement(tag.lowercased(), attrs, children)
                }
            }
            return out
        }

        private func renderInlineElement(_ tag: String, _ attrs: [String: String], _ children: [Node]) -> String {
            switch tag {
            case "strong", "b": return "**" + renderInline(children).trimmingCharacters(in: .whitespaces) + "**"
            case "em", "i":     return "*" + renderInline(children).trimmingCharacters(in: .whitespaces) + "*"
            case "code":        return "`" + plainText(children).trimmingCharacters(in: .whitespaces) + "`"
            case "br":          return "  \n"
            case "a":
                let href = attrs["href"] ?? ""
                return "[" + renderInline(children).trimmingCharacters(in: .whitespaces) + "](" + href + ")"
            case "img":
                let src = attrs["src"] ?? ""
                let alt = attrs["alt"] ?? ""
                return "![" + alt + "](" + src + ")"
            default:
                return renderInline(children) // span, unknown inline: passthrough
            }
        }

        // Concatenate only the text of children (for code / pre).
        private func plainText(_ nodes: [Node]) -> String {
            var out = ""
            for node in nodes {
                switch node {
                case .text(let raw): out += decode(raw)
                case .element(_, _, let children): out += plainText(children)
                }
            }
            return out
        }

        private func collapse(_ s: String) -> String {
            var out = ""
            var lastWasSpace = false
            for c in s {
                if c == " " || c == "\t" || c == "\n" || c == "\r" {
                    if !lastWasSpace { out.append(" "); lastWasSpace = true }
                } else {
                    out.append(c); lastWasSpace = false
                }
            }
            return out
        }

        private func decode(_ s: String) -> String {
            s.replacingOccurrences(of: "&amp;", with: "&")
                .replacingOccurrences(of: "&lt;", with: "<")
                .replacingOccurrences(of: "&gt;", with: ">")
                .replacingOccurrences(of: "&quot;", with: "\"")
                .replacingOccurrences(of: "&#39;", with: "'")
                .replacingOccurrences(of: "&nbsp;", with: " ")
        }
    }
}
