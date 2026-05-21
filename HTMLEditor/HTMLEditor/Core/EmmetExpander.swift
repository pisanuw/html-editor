import Foundation

/// Expands a useful subset of [Emmet](https://emmet.io) abbreviations into
/// indented HTML markup. Pure and Foundation-only, so it is fully unit-tested.
///
/// Supported syntax:
/// - element names, e.g. `div`
/// - id `#name`, classes `.a.b`, attributes `[href="#" title=hi]`
/// - text `{some text}`
/// - child `>`, sibling `+`, grouping `( … )`
/// - multiplication `*N`
/// - numbering `$` (a run of `$` zero-pads to that width), filled by the
///   nearest enclosing repetition (or `1` when not repeated)
///
/// `expand` returns `nil` when the input does not parse cleanly, so callers can
/// safely leave the user's text untouched.
enum EmmetExpander {

    /// HTML void elements: rendered without a closing tag.
    static let voidTags: Set<String> = [
        "area", "base", "br", "col", "embed", "hr", "img", "input",
        "link", "meta", "param", "source", "track", "wbr"
    ]

    static func expand(_ abbreviation: String, indentWidth: Int = 2, baseIndent: Int = 0) -> String? {
        let trimmed = abbreviation.trimmingCharacters(in: .whitespacesAndNewlines)
        guard let first = trimmed.first,
              first.isLetter || first == "." || first == "#" || first == "(" || first == "{"
        else { return nil }

        var parser = Parser(Array(trimmed))
        guard let nodes = parser.parseExpr(), parser.atEnd, !nodes.isEmpty else { return nil }
        nodes.forEach { Substituter.fillLeftover($0) }
        return Renderer(indentWidth: max(1, indentWidth)).render(nodes, indent: max(0, baseIndent))
    }

    // MARK: - Model

    final class Node {
        var tag: String?              // nil ⇒ raw text node (no surrounding element)
        var id: String?
        var classes: [String] = []
        var attrs: [(String, String?)] = []
        var text: String?
        var children: [Node] = []

        init(tag: String?) { self.tag = tag }

        func clone() -> Node {
            let copy = Node(tag: tag)
            copy.id = id
            copy.classes = classes
            copy.attrs = attrs
            copy.text = text
            copy.children = children.map { $0.clone() }
            return copy
        }

        var isBare: Bool {
            tag == nil && id == nil && classes.isEmpty && attrs.isEmpty
        }
    }

    // MARK: - Parser

    struct Parser {
        private let chars: [Character]
        private var i = 0

        init(_ chars: [Character]) { self.chars = chars }

        var atEnd: Bool { i >= chars.count }
        private func peek() -> Character? { i < chars.count ? chars[i] : nil }

        // expr := item ('+' item)*
        mutating func parseExpr() -> [Node]? {
            guard var nodes = parseItem() else { return nil }
            while peek() == "+" {
                i += 1
                guard let next = parseItem() else { return nil }
                nodes += next
            }
            return nodes
        }

        // item := ( '(' expr ')' | element ) ('*' N)? ('>' expr)?
        //
        // The child subtree is attached *before* multiplication, so `li*2>a`
        // repeats the whole `li>a` — i.e. it behaves like `(li>a)*2`, matching
        // Emmet. Without a climb-up operator, everything after `>` stays inside
        // that subtree (so `div>p+span` makes both p and span children of div).
        private mutating func parseItem() -> [Node]? {
            let baseNodes: [Node]
            if peek() == "(" {
                i += 1
                guard let inner = parseExpr(), peek() == ")" else { return nil }
                i += 1
                baseNodes = inner
            } else {
                guard let element = parseElement() else { return nil }
                baseNodes = [element]
            }

            let count = parseMultiplier()

            if peek() == ">" {
                i += 1
                guard let children = parseExpr(), let last = baseNodes.last else { return nil }
                last.children += children
            }

            return repeated(baseNodes, count: count)
        }

        private mutating func parseElement() -> Node? {
            let name = parseName()
            let node = Node(tag: nil)
            var sawSomething = name != nil

            loop: while let c = peek() {
                switch c {
                case "#":
                    i += 1
                    guard let id = parseName() else { return nil }
                    node.id = id
                    sawSomething = true
                case ".":
                    i += 1
                    guard let cls = parseName() else { return nil }
                    node.classes.append(cls)
                    sawSomething = true
                case "[":
                    guard parseAttrs(into: node) else { return nil }
                    sawSomething = true
                case "{":
                    guard let text = parseText() else { return nil }
                    node.text = text
                    sawSomething = true
                default:
                    break loop
                }
            }

            guard sawSomething else { return nil }
            // A standalone {text} with no element parts is a raw text node.
            if name == nil, node.isBare, node.text != nil {
                node.tag = nil
            } else {
                node.tag = name ?? "div"
            }
            return node
        }

        private mutating func parseName() -> String? {
            var out = ""
            while let c = peek(), c.isLetter || c.isNumber || c == "-" || c == "_" || c == "$" || c == ":" {
                out.append(c)
                i += 1
            }
            return out.isEmpty ? nil : out
        }

        private mutating func parseText() -> String? {
            guard peek() == "{" else { return nil }
            i += 1
            var out = ""
            while let c = peek(), c != "}" {
                out.append(c)
                i += 1
            }
            guard peek() == "}" else { return nil }
            i += 1
            return out
        }

        private mutating func parseAttrs(into node: Node) -> Bool {
            guard peek() == "[" else { return false }
            i += 1
            var content = ""
            while let c = peek(), c != "]" {
                content.append(c)
                i += 1
            }
            guard peek() == "]" else { return false }
            i += 1

            for token in tokenizeAttributes(content) {
                if let eq = token.firstIndex(of: "=") {
                    let name = String(token[..<eq])
                    let raw = String(token[token.index(after: eq)...])
                    node.attrs.append((name, stripQuotes(raw)))
                } else if !token.isEmpty {
                    node.attrs.append((token, nil))
                }
            }
            return true
        }

        private mutating func parseMultiplier() -> Int {
            guard peek() == "*" else { return 1 }
            i += 1
            var digits = ""
            while let c = peek(), c.isNumber {
                digits.append(c)
                i += 1
            }
            return Int(digits) ?? 1
        }

        // Repeat `nodes` `count` times, numbering `$` when count > 1.
        private func repeated(_ nodes: [Node], count: Int) -> [Node] {
            let n = max(count, 1)
            var out: [Node] = []
            for index in 1...n {
                for node in nodes {
                    let copy = node.clone()
                    if n > 1 { Substituter.fill(copy, index: index) }
                    out.append(copy)
                }
            }
            return out
        }

        // Split `a b="x y" c=d` honoring quotes.
        private func tokenizeAttributes(_ s: String) -> [String] {
            var tokens: [String] = []
            var current = ""
            var quote: Character?
            for c in s {
                if let q = quote {
                    current.append(c)
                    if c == q { quote = nil }
                } else if c == "\"" || c == "'" {
                    quote = c
                    current.append(c)
                } else if c == " " {
                    if !current.isEmpty { tokens.append(current); current = "" }
                } else {
                    current.append(c)
                }
            }
            if !current.isEmpty { tokens.append(current) }
            return tokens
        }

        private func stripQuotes(_ s: String) -> String {
            guard s.count >= 2, let f = s.first, let l = s.last, f == l, f == "\"" || f == "'" else { return s }
            return String(s.dropFirst().dropLast())
        }
    }

    // MARK: - $ numbering

    private enum Substituter {
        static func fill(_ node: Node, index: Int) {
            node.tag = node.tag.map { number($0, index) }
            node.id = node.id.map { number($0, index) }
            node.classes = node.classes.map { number($0, index) }
            node.attrs = node.attrs.map { ($0.0, $0.1.map { number($0, index) }) }
            node.text = node.text.map { number($0, index) }
            node.children.forEach { fill($0, index: index) }
        }

        /// Replace any `$` runs that survived (unrepeated) with `1`.
        static func fillLeftover(_ node: Node) {
            if containsDollar(node) { fill(node, index: 1) }
            node.children.forEach { fillLeftover($0) }
        }

        private static func containsDollar(_ node: Node) -> Bool {
            (node.tag?.contains("$") ?? false)
                || (node.id?.contains("$") ?? false)
                || node.classes.contains { $0.contains("$") }
                || node.attrs.contains { ($0.1?.contains("$") ?? false) }
                || (node.text?.contains("$") ?? false)
        }

        private static func number(_ s: String, _ index: Int) -> String {
            guard s.contains("$") else { return s }
            var out = ""
            var run = 0
            for c in s {
                if c == "$" {
                    run += 1
                } else {
                    if run > 0 { out += pad(index, width: run); run = 0 }
                    out.append(c)
                }
            }
            if run > 0 { out += pad(index, width: run) }
            return out
        }

        private static func pad(_ n: Int, width: Int) -> String {
            let s = String(n)
            return s.count >= width ? s : String(repeating: "0", count: width - s.count) + s
        }
    }

    // MARK: - Renderer

    private struct Renderer {
        let indentWidth: Int

        func render(_ nodes: [Node], indent: Int) -> String {
            nodes.map { renderNode($0, indent: indent) }.joined(separator: "\n")
        }

        private func renderNode(_ node: Node, indent: Int) -> String {
            let pad = String(repeating: " ", count: indent * indentWidth)

            guard let tag = node.tag else {            // raw text node
                return pad + (node.text ?? "")
            }

            let open = "<" + tag + attributeString(node) + ">"

            if EmmetExpander.voidTags.contains(tag.lowercased()) {
                return pad + open
            }
            if node.children.isEmpty {
                return pad + open + (node.text ?? "") + "</" + tag + ">"
            }

            var lines = [pad + open]
            for child in node.children {
                lines.append(renderNode(child, indent: indent + 1))
            }
            lines.append(pad + "</" + tag + ">")
            return lines.joined(separator: "\n")
        }

        private func attributeString(_ node: Node) -> String {
            var s = ""
            if let id = node.id { s += " id=\"\(id)\"" }
            if !node.classes.isEmpty { s += " class=\"\(node.classes.joined(separator: " "))\"" }
            for (name, value) in node.attrs {
                if let value = value { s += " \(name)=\"\(value)\"" } else { s += " \(name)" }
            }
            return s
        }
    }
}
