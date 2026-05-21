import Foundation
import Combine

/// Owns the set of open documents (tabs) and tracks which one is active.
/// The app has a single window; tabs switch the document shown in the editor
/// and preview.
final class Workspace: ObservableObject {
    @Published private(set) var documents: [DocumentModel]
    @Published var activeID: UUID

    init() {
        let first = DocumentModel()
        documents = [first]
        activeID = first.id
    }

    /// The currently active document. Falls back to the first document if the
    /// active id is ever stale (should not happen in practice).
    var activeDocument: DocumentModel {
        documents.first { $0.id == activeID } ?? documents[0]
    }

    func select(_ id: UUID) {
        activeID = id
    }

    /// Open a fresh empty tab and make it active.
    func newTab() {
        let doc = DocumentModel()
        documents.append(doc)
        activeID = doc.id
    }

    /// Prompt for a file and, if one is chosen, open it in a new tab.
    func openInNewTab() {
        let doc = DocumentModel()
        if doc.openDocument() {
            documents.append(doc)
            activeID = doc.id
        }
    }

    func closeActiveTab() {
        close(activeID)
    }

    /// Close a tab. The last remaining tab is never closed (keeping at least
    /// one document open keeps the editor non-empty).
    func close(_ id: UUID) {
        guard documents.count > 1,
              let index = documents.firstIndex(where: { $0.id == id }) else { return }
        documents.remove(at: index)
        if activeID == id {
            let next = min(index, documents.count - 1)
            activeID = documents[next].id
        }
    }
}
