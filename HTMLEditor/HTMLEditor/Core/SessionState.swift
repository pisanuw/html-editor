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

/// One restorable tab: a file path (file-backed) and/or unsaved text (untitled
/// or unsaved buffer). `text` is stored for tabs without a path so untitled
/// work survives a relaunch.
struct SessionTab: Codable, Equatable {
    var path: String?
    var title: String
    var text: String?

    init(path: String? = nil, title: String, text: String? = nil) {
        self.path = path
        self.title = title
        self.text = text
    }
}

/// The set of open tabs to restore on relaunch.
struct SessionState: Codable, Equatable {
    var tabs: [SessionTab]
    var activeIndex: Int

    init(tabs: [SessionTab] = [], activeIndex: Int = 0) {
        self.tabs = tabs
        self.activeIndex = activeIndex
    }

    /// The active index clamped to a valid position for `tabs`.
    var safeActiveIndex: Int {
        guard !tabs.isEmpty else { return 0 }
        return min(max(activeIndex, 0), tabs.count - 1)
    }

    func encoded() -> Data? { try? JSONEncoder().encode(self) }
    static func decoded(from data: Data) -> SessionState? { try? JSONDecoder().decode(SessionState.self, from: data) }
}
