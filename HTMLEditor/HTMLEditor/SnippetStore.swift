import SwiftUI

/// Persists the user's snippet library to `UserDefaults` (as JSON via
/// `SnippetLibrary`) and publishes changes to SwiftUI. The pure model and codec
/// live in `Core/Snippet.swift`; this is the thin storage shell.
final class SnippetStore: ObservableObject {
    @Published var library: SnippetLibrary { didSet { persist() } }
    @Published var showingManager = false

    private let key = "HTMLEditor.snippets"

    init() {
        if let data = UserDefaults.standard.data(forKey: key),
           let restored = SnippetLibrary.decoded(from: data) {
            library = restored
        } else {
            library = .defaults
        }
    }

    func add() {
        library.snippets.append(Snippet(name: "New snippet", trigger: "new", body: ""))
    }

    func remove(at offsets: IndexSet) {
        library.snippets.remove(atOffsets: offsets)
    }

    private func persist() {
        guard let data = library.encoded() else { return }
        UserDefaults.standard.set(data, forKey: key)
    }
}
