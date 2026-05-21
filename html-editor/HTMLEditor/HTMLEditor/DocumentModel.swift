import Foundation
import AppKit
import UniformTypeIdentifiers

class DocumentModel: ObservableObject {
    @Published var htmlText: String = Self.defaultHTML
    @Published var fileURL: URL?
    @Published var windowTitle: String = "Untitled"
    @Published var cursorLine: Int = 1
    @Published var cursorColumn: Int = 1

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
    }

    func openDocument() {
        let panel = NSOpenPanel()
        panel.allowedContentTypes = [.html]
        panel.allowsMultipleSelection = false
        guard panel.runModal() == .OK, let url = panel.url else { return }
        guard let content = try? String(contentsOf: url, encoding: .utf8) else { return }
        htmlText = content
        fileURL = url
        windowTitle = url.lastPathComponent
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
        panel.nameFieldStringValue = "index.html"
        guard panel.runModal() == .OK, let url = panel.url else { return }
        write(to: url)
    }

    func updateCursor(in string: String, at location: Int) {
        var line = 1
        var lineStart = 0
        let nsString = string as NSString
        let end = min(location, nsString.length)
        for i in 0..<end {
            if nsString.character(at: i) == 10 {
                line += 1
                lineStart = i + 1
            }
        }
        cursorLine = line
        cursorColumn = location - lineStart + 1
    }

    private func write(to url: URL) {
        try? htmlText.write(to: url, atomically: true, encoding: .utf8)
        fileURL = url
        windowTitle = url.lastPathComponent
    }
}
