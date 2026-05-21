import Foundation

/// Pure transforms backing the editor's export options. The AppKit layer turns
/// these into files / PDFs; the string logic lives here so it can be tested.
enum HTMLExporter {

    /// Collapse a document for distribution: strip comments and redundant
    /// whitespace between tags while preserving the contents of `pre`,
    /// `textarea`, `script`, and `style`.
    static func minify(_ html: String) -> String {
        var result = stripComments(html)
        result = collapseBetweenTags(result, preserving: ["pre", "textarea", "script", "style"])
        return result.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    /// Ensure the markup is a complete, standalone document. If it already has
    /// an `<html>` root it is returned unchanged (aside from a guaranteed
    /// doctype); otherwise it is wrapped in a minimal HTML5 skeleton.
    static func standaloneDocument(_ html: String, title: String = "Document") -> String {
        let trimmed = html.trimmingCharacters(in: .whitespacesAndNewlines)
        if trimmed.range(of: "<html", options: .caseInsensitive) != nil {
            return hasDoctype(trimmed) ? trimmed : "<!DOCTYPE html>\n" + trimmed
        }
        let safeTitle = escape(title)
        return """
        <!DOCTYPE html>
        <html lang="en">
        <head>
            <meta charset="UTF-8">
            <meta name="viewport" content="width=device-width, initial-scale=1.0">
            <title>\(safeTitle)</title>
        </head>
        <body>
        \(trimmed)
        </body>
        </html>
        """
    }

    /// Extract the inner contents of `<body>…</body>`. If there is no body tag,
    /// the trimmed input is returned (it is assumed to already be a fragment).
    static func bodyFragment(_ html: String) -> String {
        guard let open = html.range(of: "<body", options: .caseInsensitive),
              let openEnd = html.range(of: ">", range: open.lowerBound..<html.endIndex),
              let close = html.range(of: "</body>", options: .caseInsensitive,
                                     range: openEnd.upperBound..<html.endIndex)
        else {
            return html.trimmingCharacters(in: .whitespacesAndNewlines)
        }
        return String(html[openEnd.upperBound..<close.lowerBound])
            .trimmingCharacters(in: .whitespacesAndNewlines)
    }

    /// A safe default filename derived from the document `<title>`, falling back
    /// to `index`. Always ends in `.html`.
    static func suggestedFilename(for html: String) -> String {
        let title = documentTitle(html) ?? "index"
        let slug = title
            .lowercased()
            .replacingOccurrences(of: "[^a-z0-9]+", with: "-", options: .regularExpression)
            .trimmingCharacters(in: CharacterSet(charactersIn: "-"))
        return (slug.isEmpty ? "index" : slug) + ".html"
    }

    // MARK: - Private

    private static func stripComments(_ html: String) -> String {
        guard let regex = try? NSRegularExpression(pattern: "<!--[\\s\\S]*?-->") else { return html }
        let range = NSRange(location: 0, length: (html as NSString).length)
        return regex.stringByReplacingMatches(in: html, range: range, withTemplate: "")
    }

    /// Collapse whitespace runs that sit entirely between tags (`>   <` → `><`)
    /// and trim leading/trailing whitespace on text runs, while leaving the
    /// interior of preserved elements alone.
    private static func collapseBetweenTags(_ html: String, preserving tags: Set<String>) -> String {
        let segments = splitPreserving(html, tags: tags)
        return segments.map { segment in
            segment.preserved ? segment.text : collapse(segment.text)
        }.joined()
    }

    private static func collapse(_ text: String) -> String {
        var result = text
        // Whitespace between adjacent tags disappears entirely.
        result = result.replacingOccurrences(of: ">\\s+<", with: "><", options: .regularExpression)
        // Any remaining whitespace run becomes a single space.
        result = result.replacingOccurrences(of: "\\s{2,}", with: " ", options: .regularExpression)
        result = result.replacingOccurrences(of: "[\\t\\n\\r]+", with: " ", options: .regularExpression)
        return result
    }

    private struct Segment { let text: String; let preserved: Bool }

    /// Split `html` into segments, marking the interior (and tags) of preserved
    /// elements so they are copied verbatim by the minifier.
    private static func splitPreserving(_ html: String, tags: Set<String>) -> [Segment] {
        guard !tags.isEmpty else { return [Segment(text: html, preserved: false)] }
        let alternation = tags.sorted().joined(separator: "|")
        let pattern = "<(\(alternation))\\b[\\s\\S]*?</\\1>"
        guard let regex = try? NSRegularExpression(pattern: pattern, options: .caseInsensitive) else {
            return [Segment(text: html, preserved: false)]
        }
        let ns = html as NSString
        let full = NSRange(location: 0, length: ns.length)

        var segments: [Segment] = []
        var cursor = 0
        for match in regex.matches(in: html, range: full) {
            if match.range.location > cursor {
                segments.append(Segment(text: ns.substring(with: NSRange(
                    location: cursor, length: match.range.location - cursor)), preserved: false))
            }
            segments.append(Segment(text: ns.substring(with: match.range), preserved: true))
            cursor = match.range.location + match.range.length
        }
        if cursor < ns.length {
            segments.append(Segment(text: ns.substring(from: cursor), preserved: false))
        }
        return segments
    }

    private static func documentTitle(_ html: String) -> String? {
        guard let regex = try? NSRegularExpression(pattern: "<title[^>]*>([\\s\\S]*?)</title>",
                                                   options: .caseInsensitive) else { return nil }
        let ns = html as NSString
        let full = NSRange(location: 0, length: ns.length)
        guard let match = regex.firstMatch(in: html, range: full), match.numberOfRanges > 1 else {
            return nil
        }
        let title = ns.substring(with: match.range(at: 1)).trimmingCharacters(in: .whitespacesAndNewlines)
        return title.isEmpty ? nil : title
    }

    private static func hasDoctype(_ html: String) -> Bool {
        html.range(of: "<!DOCTYPE", options: .caseInsensitive) != nil
    }

    private static func escape(_ text: String) -> String {
        text.replacingOccurrences(of: "&", with: "&amp;")
            .replacingOccurrences(of: "<", with: "&lt;")
            .replacingOccurrences(of: ">", with: "&gt;")
    }
}
