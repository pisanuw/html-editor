import Foundation
import AppKit
import UniformTypeIdentifiers
import Combine

/// A single open document (one editor tab). Owns its text, file association,
/// cursor position, and the selection to restore when its tab is reactivated.
class DocumentModel: ObservableObject, Identifiable {
    let id = UUID()

    @Published var htmlText: String = DocumentModel.defaultHTML
    @Published var fileURL: URL?
    @Published var windowTitle: String = "Untitled"
    @Published var cursorLine: Int = 1
    @Published var cursorColumn: Int = 1

    /// Selection to restore when this document's tab becomes active again.
    /// Updated as the user moves the caret; consumed by `EditorView`.
    var savedSelection: NSRange?

    private static let defaultHTML = """
    <!DOCTYPE html>
    <html>
    <head>
        <meta charset="UTF-8">
        <title>My Page</title>
        <style>
            body { font-family: sans-serif; margin: 2em; }
        </style>
    </head>
    <body>
        <h1>Hello, World!</h1>
        <p>Start editing HTML here…</p>
    </body>
    </html>
    """

    func newDocument() {
        htmlText = Self.defaultHTML
        fileURL = nil
        windowTitle = "Untitled"
        savedSelection = nil
    }

    @discardableResult
    func openDocument() -> Bool {
        let panel = NSOpenPanel()
        panel.allowedContentTypes = [.html]
        panel.allowsMultipleSelection = false
        guard panel.runModal() == .OK, let url = panel.url else { return false }
        guard let content = try? String(contentsOf: url, encoding: .utf8) else { return false }
        htmlText = content
        fileURL = url
        windowTitle = url.lastPathComponent
        savedSelection = nil
        return true
    }

    func saveDocument() {
        if let url = fileURL {
            write(to: url)
        } else {
            saveDocumentAs()
        }
    }

    func saveDocumentAs() {
        let panel = NSSavePanel()
        panel.allowedContentTypes = [.html]
        panel.nameFieldStringValue = HTMLExporter.suggestedFilename(for: htmlText)
        guard panel.runModal() == .OK, let url = panel.url else { return }
        write(to: url)
    }

    func updateCursor(in string: String, at location: Int) {
        let position = TextMetrics.lineColumn(in: string, at: location)
        cursorLine = position.line
        cursorColumn = position.column
    }

    private func write(to url: URL) {
        try? htmlText.write(to: url, atomically: true, encoding: .utf8)
        fileURL = url
        windowTitle = url.lastPathComponent
    }
}
