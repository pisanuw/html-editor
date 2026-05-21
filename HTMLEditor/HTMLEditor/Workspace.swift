import Foundation
import AppKit
import Combine

/// Owns the set of open documents (tabs) and tracks which one is active.
/// Persists the open-tab session (including untitled buffers) and a recent-files
/// list across launches, and keeps a stack of recently closed tabs for reopen.
final class Workspace: ObservableObject {
    @Published private(set) var documents: [DocumentModel]
    @Published var activeID: UUID {
        didSet { persistSession() }
    }
    @Published private(set) var recent: RecentFiles

    private let sessionKey = "HTMLEditor.session"
    private let recentKey = "HTMLEditor.recent"
    private var closedTabs: [SessionTab] = []

    init() {
        recent = Workspace.loadRecent()

        let session = Workspace.loadSession()
        var docs = session.tabs.compactMap { Workspace.makeDocument(from: $0) }
        if docs.isEmpty { docs = [DocumentModel()] }
        documents = docs
        let index = min(max(session.safeActiveIndex, 0), docs.count - 1)
        activeID = docs[index].id

        NotificationCenter.default.addObserver(
            forName: NSApplication.willTerminateNotification, object: nil, queue: .main) { [weak self] _ in
            self?.persistSession()
        }
    }

    var activeDocument: DocumentModel {
        documents.first { $0.id == activeID } ?? documents[0]
    }

    var recentURLs: [URL] { recent.paths.map { URL(fileURLWithPath: $0) } }
    var canReopenClosed: Bool { !closedTabs.isEmpty }

    func select(_ id: UUID) { activeID = id }

    func newTab() {
        let doc = DocumentModel()
        documents.append(doc)
        activeID = doc.id
    }

    func openInNewTab() {
        let doc = DocumentModel()
        if doc.openDocument() {
            documents.append(doc)
            activeID = doc.id
            if let path = doc.fileURL?.path { noteRecent(path) }
        }
    }

    /// Open a specific file in a new tab (drag-and-drop, recent files, session).
    @discardableResult
    func open(url: URL) -> Bool {
        if let existing = documents.first(where: { $0.fileURL == url }) {
            activeID = existing.id
            return true
        }
        guard let doc = DocumentModel(contentsOf: url) else { return false }
        documents.append(doc)
        activeID = doc.id
        noteRecent(url.path)
        return true
    }

    func saveActive() {
        let doc = activeDocument
        doc.saveDocument()
        if let path = doc.fileURL?.path { noteRecent(path) }
        persistSession()
    }

    func saveActiveAs() {
        let doc = activeDocument
        doc.saveDocumentAs()
        if let path = doc.fileURL?.path { noteRecent(path) }
        persistSession()
    }

    func closeActiveTab() { close(activeID) }

    func close(_ id: UUID) {
        guard documents.count > 1,
              let index = documents.firstIndex(where: { $0.id == id }) else { return }
        pushClosed(documents[index])
        documents.remove(at: index)
        if activeID == id {
            let next = min(index, documents.count - 1)
            activeID = documents[next].id
        } else {
            persistSession()
        }
    }

    /// Reopen the most recently closed tab.
    func reopenLastClosed() {
        guard let tab = closedTabs.popLast() else { return }
        if let path = tab.path {
            open(url: URL(fileURLWithPath: path))
            return
        }
        let doc = DocumentModel()
        if let text = tab.text { doc.htmlText = text }
        doc.windowTitle = tab.title.isEmpty ? "Untitled" : tab.title
        documents.append(doc)
        activeID = doc.id
    }

    /// Reveal a range in a (possibly other) tab — used by find-across-tabs.
    func focus(_ id: UUID, selection: NSRange) {
        if let doc = documents.first(where: { $0.id == id }) {
            doc.savedSelection = selection
        }
        activeID = id
    }

    // MARK: - Persistence

    private func pushClosed(_ doc: DocumentModel) {
        closedTabs.append(descriptor(for: doc))
        if closedTabs.count > 20 { closedTabs.removeFirst() }
    }

    private func descriptor(for doc: DocumentModel) -> SessionTab {
        if let path = doc.fileURL?.path {
            return SessionTab(path: path, title: doc.windowTitle)
        }
        return SessionTab(path: nil, title: doc.windowTitle, text: doc.htmlText)
    }

    private func noteRecent(_ path: String) {
        recent.add(path)
        if let data = recent.encoded() { UserDefaults.standard.set(data, forKey: recentKey) }
        persistSession()
    }

    private func persistSession() {
        let tabs = documents.map { descriptor(for: $0) }
        let activeIndex = documents.firstIndex { $0.id == activeID } ?? 0
        let state = SessionState(tabs: tabs, activeIndex: activeIndex)
        if let data = state.encoded() { UserDefaults.standard.set(data, forKey: sessionKey) }
    }

    private static func makeDocument(from tab: SessionTab) -> DocumentModel? {
        if let path = tab.path {
            return DocumentModel(contentsOf: URL(fileURLWithPath: path))
        }
        let doc = DocumentModel()
        if let text = tab.text { doc.htmlText = text }
        doc.windowTitle = tab.title.isEmpty ? "Untitled" : tab.title
        return doc
    }

    private static func loadSession() -> SessionState {
        guard let data = UserDefaults.standard.data(forKey: "HTMLEditor.session"),
              let state = SessionState.decoded(from: data) else { return SessionState() }
        return state
    }

    private static func loadRecent() -> RecentFiles {
        guard let data = UserDefaults.standard.data(forKey: "HTMLEditor.recent"),
              let recent = RecentFiles.decoded(from: data) else { return RecentFiles() }
        return recent
    }
}
