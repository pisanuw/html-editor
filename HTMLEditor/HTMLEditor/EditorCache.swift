import AppKit
import Combine

/// Caches one `NSScrollView` (and its `NSTextView`) per document id. Because the
/// same text view is reused when you switch back to a tab, its built-in undo
/// stack and text storage survive tab switches instead of being rebuilt.
final class EditorCache: ObservableObject {
    private var views: [UUID: NSScrollView] = [:]
    private var folders: [UUID: FoldingController] = [:]

    init() {
        NotificationCenter.default.addObserver(
            forName: .documentClosed, object: nil, queue: .main) { [weak self] note in
            if let id = note.object as? UUID { self?.discard(id) }
        }
    }

    func scrollView(for id: UUID) -> NSScrollView? { views[id] }
    func store(_ view: NSScrollView, for id: UUID) { views[id] = view }

    func foldingController(for id: UUID) -> FoldingController? { folders[id] }
    func store(_ controller: FoldingController, for id: UUID) { folders[id] = controller }

    func discard(_ id: UUID) {
        views[id] = nil
        folders[id] = nil
    }
}

extension Notification.Name {
    static let documentClosed = Notification.Name("HTMLEditor.documentClosed")
}
