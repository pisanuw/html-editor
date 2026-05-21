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

    /// Set when the file changes on disk and differs from the buffer; the UI
    /// shows a reload banner.
    @Published var externalChangePending = false

    /// Selection to restore when this document's tab becomes active again.
    var savedSelection: NSRange?

    private let watcher = FileWatcher()

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

    init() {}

    /// Create a document bound to an existing file (used by session restore and
    /// drag-and-drop). Returns nil if the file can't be read.
    convenience init?(contentsOf url: URL) {
        self.init()
        guard let content = try? String(contentsOf: url, encoding: .utf8) else { return nil }
        htmlText = content
        fileURL = url
        windowTitle = url.lastPathComponent
        startWatching()
    }

    func newDocument() {
        htmlText = Self.defaultHTML
        fileURL = nil
        windowTitle = "Untitled"
        savedSelection = nil
        watcher.stop()
    }

    @discardableResult
    func openDocument() -> Bool {
        let panel = NSOpenPanel()
        panel.allowedContentTypes = [.html]
        panel.allowsMultipleSelection = false
        guard panel.runModal() == .OK, let url = panel.url else { return false }
        return load(url: url)
    }

    @discardableResult
    func load(url: URL) -> Bool {
        guard let content = try? String(contentsOf: url, encoding: .utf8) else { return false }
        htmlText = content
        fileURL = url
        windowTitle = url.lastPathComponent
        savedSelection = nil
        externalChangePending = false
        startWatching()
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

    /// Reload the buffer from the file on disk (discards unsaved edits).
    func reloadFromDisk() {
        guard let url = fileURL,
              let content = try? String(contentsOf: url, encoding: .utf8) else { return }
        htmlText = content
        externalChangePending = false
    }

    func ignoreExternalChange() {
        externalChangePending = false
    }

    func updateCursor(in string: String, at location: Int) {
        let position = TextMetrics.lineColumn(in: string, at: location)
        cursorLine = position.line
        cursorColumn = position.column
    }

    // MARK: - Private

    private func write(to url: URL) {
        try? htmlText.write(to: url, atomically: true, encoding: .utf8)
        fileURL = url
        windowTitle = url.lastPathComponent
        externalChangePending = false
        startWatching()
    }

    private func startWatching() {
        guard let url = fileURL else { return }
        watcher.onChange = { [weak self] in
            guard let self, let url = self.fileURL else { return }
            // Only prompt if the on-disk content actually differs from ours
            // (so our own saves don't trigger a reload banner).
            let onDisk = try? String(contentsOf: url, encoding: .utf8)
            if let onDisk, onDisk != self.htmlText {
                self.externalChangePending = true
            }
        }
        watcher.watch(url)
    }

    deinit {
        watcher.stop()
        NotificationCenter.default.post(name: .documentClosed, object: id)
    }
}
