import Foundation

/// A reusable text snippet the user can insert into the editor.
struct Snippet: Codable, Identifiable, Equatable {
    var id: UUID
    var name: String
    var trigger: String   // short keyword, optionally expandable
    var body: String

    init(id: UUID = UUID(), name: String, trigger: String, body: String) {
        self.id = id
        self.name = name
        self.trigger = trigger
        self.body = body
    }
}

/// A collection of snippets, with JSON persistence and trigger lookup. Pure and
/// Foundation-only so the encoding/lookup behavior is unit-tested; the UI layer
/// adds UserDefaults storage on top.
struct SnippetLibrary: Codable, Equatable {
    var snippets: [Snippet]

    init(snippets: [Snippet]) { self.snippets = snippets }

    /// Starter snippets shown the first time the library is used.
    static var defaults: SnippetLibrary {
        SnippetLibrary(snippets: [
            Snippet(name: "HTML5 boilerplate", trigger: "html5", body: """
            <!DOCTYPE html>
            <html lang="en">
            <head>
                <meta charset="UTF-8">
                <meta name="viewport" content="width=device-width, initial-scale=1.0">
                <title>Document</title>
            </head>
            <body>

            </body>
            </html>
            """),
            Snippet(name: "Anchor link", trigger: "a", body: "<a href=\"#\"></a>"),
            Snippet(name: "Image", trigger: "img", body: #"<img src="" alt="">"#),
            Snippet(name: "Table 2×2", trigger: "table", body: """
            <table>
              <tr><th></th><th></th></tr>
              <tr><td></td><td></td></tr>
            </table>
            """),
            Snippet(name: "Flex container", trigger: "flex", body: """
            <div style="display: flex; gap: 1rem;">

            </div>
            """)
        ])
    }

    /// First snippet whose trigger matches `trigger` (case-insensitive).
    func snippet(forTrigger trigger: String) -> Snippet? {
        let key = trigger.lowercased()
        return snippets.first { $0.trigger.lowercased() == key }
    }

    func encoded() -> Data? {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        return try? encoder.encode(self)
    }

    static func decoded(from data: Data) -> SnippetLibrary? {
        try? JSONDecoder().decode(SnippetLibrary.self, from: data)
    }
}
