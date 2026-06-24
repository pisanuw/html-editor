import Foundation
import AppKit
import UniformTypeIdentifiers
import Combine

/// Diff status for a single line: added (no counterpart in baseline) or
/// modified (content differs from baseline at that index).
enum DiffMarker { case added, modified }

/// A single open document (one editor tab). Owns its text, file association,
/// cursor position, and the selection to restore when its tab is reactivated.
class DocumentModel: ObservableObject, Identifiable {
    let id = UUID()

    @Published var htmlText: String = DocumentModel.defaultHTML
    @Published var fileURL: URL?
    @Published var windowTitle: String = "Untitled"
    @Published var cursorLine: Int = 1
    @Published var cursorColumn: Int = 1
    @Published var cursorOffset: Int = 0

    /// Set when the file changes on disk and differs from the buffer; the UI
    /// shows a reload banner.
    @Published var externalChangePending = false

    /// Set when a save or reload fails; the UI shows an error banner. Cleared
    /// on the next successful save/reload. A non-nil value means the on-disk
    /// file may not reflect the buffer, so the user must not assume their work
    /// is persisted.
    @Published var fileError: String?

    /// When true, save automatically 2 s after the last edit (only for files
    /// that already have a URL — untitled buffers are never auto-saved).
    @Published var autoSave: Bool = false {
        didSet { autoSave ? startAutoSave() : cancelAutoSave() }
    }

    /// The text at the last save/load; used to compute per-line diff markers.
    private(set) var savedBaseline: String?

    /// Maps 0-based line index to its diff status (added or modified vs saved
    /// baseline). Empty when no baseline has been established (new document).
    @Published var lineDiffs: [Int: DiffMarker] = [:]

    /// Selection to restore when this document's tab becomes active again.
    var savedSelection: NSRange?

    private let watcher = FileWatcher()
    private var autoSaveCancellable: AnyCancellable?
    private var diffCancellable: AnyCancellable?

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

    init() {
        diffCancellable = $htmlText
            .dropFirst()
            .sink { [weak self] _ in self?.updateDiff() }
    }

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
        savedBaseline = content
        lineDiffs = [:]
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
        guard let url = fileURL else { return }
        do {
            htmlText = try String(contentsOf: url, encoding: .utf8)
            externalChangePending = false
            fileError = nil
        } catch {
            fileError = "Could not reload \(url.lastPathComponent): \(error.localizedDescription)"
        }
    }

    func ignoreExternalChange() {
        externalChangePending = false
    }

    func updateCursor(in string: String, at location: Int) {
        let position = TextMetrics.lineColumn(in: string, at: location)
        cursorLine = position.line
        cursorColumn = position.column
        cursorOffset = location
    }

    // MARK: - Auto-save

    private func startAutoSave() {
        autoSaveCancellable = $htmlText
            .debounce(for: .seconds(2), scheduler: RunLoop.main)
            .sink { [weak self] _ in
                guard let self, self.autoSave, let url = self.fileURL else { return }
                if !self.write(to: url) {
                    // A failed write would otherwise repeat on every keystroke,
                    // beeping endlessly. Stop auto-saving and leave the error
                    // banner up so the user can resolve it and save manually.
                    self.autoSave = false
                }
            }
    }

    private func cancelAutoSave() {
        autoSaveCancellable = nil
    }

    // MARK: - Private

    /// Persist the buffer to `url`. Returns whether the write succeeded. The
    /// dirty/diff baseline is advanced *only* on success, so a failed write
    /// keeps the document marked dirty instead of silently discarding the user's
    /// changes.
    @discardableResult
    private func write(to url: URL) -> Bool {
        switch DocumentSaver.save(htmlText, to: url) {
        case .saved(let baseline):
            fileError = nil
            fileURL = url
            windowTitle = url.lastPathComponent
            externalChangePending = false
            savedBaseline = baseline
            lineDiffs = [:]
            startWatching()
            return true
        case .failed(let message):
            fileError = "Could not save \(url.lastPathComponent): \(message)"
            NSSound.beep()
            return false
        }
    }

    // MARK: - Diff

    private func updateDiff() {
        guard let baseline = savedBaseline else { lineDiffs = [:]; return }
        let currentLines = htmlText.components(separatedBy: "\n")
        let baselineLines = baseline.components(separatedBy: "\n")
        var result: [Int: DiffMarker] = [:]
        for (i, line) in currentLines.enumerated() {
            if i >= baselineLines.count {
                result[i] = .added
            } else if line != baselineLines[i] {
                result[i] = .modified
            }
        }
        lineDiffs = result
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
