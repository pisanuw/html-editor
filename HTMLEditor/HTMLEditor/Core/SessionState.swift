import Foundation

/// A most-recently-used list of file paths: de-duplicated, newest first, capped.
struct RecentFiles: Codable, Equatable {
    private(set) var paths: [String]
    var limit: Int

    init(paths: [String] = [], limit: Int = 10) {
        self.limit = max(1, limit)
        self.paths = Array(paths.prefix(self.limit))
    }

    mutating func add(_ path: String) {
        guard !path.isEmpty else { return }
        paths.removeAll { $0 == path }
        paths.insert(path, at: 0)
        if paths.count > limit { paths.removeLast(paths.count - limit) }
    }

    mutating func remove(_ path: String) {
        paths.removeAll { $0 == path }
    }

    func encoded() -> Data? { try? JSONEncoder().encode(self) }
    static func decoded(from data: Data) -> RecentFiles? { try? JSONDecoder().decode(RecentFiles.self, from: data) }
}

/// The set of open documents to restore on relaunch.
struct SessionState: Codable, Equatable {
    var openPaths: [String]
    var activeIndex: Int

    init(openPaths: [String] = [], activeIndex: Int = 0) {
        self.openPaths = openPaths
        self.activeIndex = activeIndex
    }

    /// The active index clamped to a valid position for `openPaths`.
    var safeActiveIndex: Int {
        guard !openPaths.isEmpty else { return 0 }
        return min(max(activeIndex, 0), openPaths.count - 1)
    }

    func encoded() -> Data? { try? JSONEncoder().encode(self) }
    static func decoded(from data: Data) -> SessionState? { try? JSONDecoder().decode(SessionState.self, from: data) }
}
