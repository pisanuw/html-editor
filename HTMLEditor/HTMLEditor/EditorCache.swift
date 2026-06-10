import AppKit
import Combine

/// Caches one `NSScrollView` (and its `NSTextView`) per document id. Because the
/// same text view is reused when you switch back to a tab, its built-in undo
/// stack and text storage survive tab switches instead of being rebuilt.
final class EditorCache: ObservableObject {
    private var views = IDKeyedStore<NSScrollView>()
    private var folders = IDKeyedStore<FoldingController>()

    init() {
        NotificationCenter.default.addObserver(
            forName: .documentClosed, object: nil, queue: .main) { [weak self] note in
            if let id = note.object as? UUID { self?.discard(id) }
        }
    }

    func scrollView(for id: UUID) -> NSScrollView? { views.value(for: id) }
    func store(_ view: NSScrollView, for id: UUID) { views.store(view, for: id) }

    func foldingController(for id: UUID) -> FoldingController? { folders.value(for: id) }
    func store(_ controller: FoldingController, for id: UUID) { folders.store(controller, for: id) }

    func discard(_ id: UUID) {
        views.discard(id)
        folders.discard(id)
    }
}

extension Notification.Name {
    static let documentClosed = Notification.Name("HTMLEditor.documentClosed")
}
