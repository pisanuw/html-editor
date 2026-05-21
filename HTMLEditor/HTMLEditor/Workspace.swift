import Foundation
import Combine

/// Owns the set of open documents (tabs) and tracks which one is active.
/// Persists the open-file session and a recent-files list across launches.
final class Workspace: ObservableObject {
    @Published private(set) var documents: [DocumentModel]
    @Published var activeID: UUID {
        didSet { persistSession() }
    }
    @Published private(set) var recent: RecentFiles

    private let sessionKey = "HTMLEditor.session"
    private let recentKey = "HTMLEditor.recent"

    init() {
        recent = Workspace.loadRecent()

        let session = Workspace.loadSession()
        var docs = session.openPaths.compactMap { DocumentModel(contentsOf: URL(fileURLWithPath: $0)) }
        if docs.isEmpty { docs = [DocumentModel()] }
        documents = docs
        let index = min(max(session.safeActiveIndex, 0), docs.count - 1)
        activeID = docs[index].id
    }

    var activeDocument: DocumentModel {
        documents.first { $0.id == activeID } ?? documents[0]
    }

    var recentURLs: [URL] { recent.paths.map { URL(fileURLWithPath: $0) } }

    func select(_ id: UUID) { activeID = id }

    func newTab() {
        let doc = DocumentModel()
        documents.append(doc)
        activeID = doc.id
    }

    /// Prompt for a file and open it in a new tab.
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
        // If already open, just focus it.
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

    /// Save the active document and record it in recents / session.
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
        documents.remove(at: index)
        if activeID == id {
            let next = min(index, documents.count - 1)
            activeID = documents[next].id
        } else {
            persistSession()
        }
    }

    // MARK: - Persistence

    private func noteRecent(_ path: String) {
        recent.add(path)
        if let data = recent.encoded() { UserDefaults.standard.set(data, forKey: recentKey) }
        persistSession()
    }

    private func persistSession() {
        let paths = documents.compactMap { $0.fileURL?.path }
        let activePath = activeDocument.fileURL?.path
        let activeIndex = activePath.flatMap { paths.firstIndex(of: $0) } ?? 0
        let state = SessionState(openPaths: paths, activeIndex: activeIndex)
        if let data = state.encoded() { UserDefaults.standard.set(data, forKey: sessionKey) }
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
