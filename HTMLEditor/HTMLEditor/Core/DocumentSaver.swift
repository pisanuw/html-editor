import Foundation

/// Outcome of attempting to persist a document to disk.
enum SaveResult: Equatable {
    /// The write succeeded. `baseline` is the text now on disk; the caller
    /// should adopt it as the new diff/dirty baseline.
    case saved(baseline: String)
    /// The write failed. `message` is a human-readable description. No durable
    /// data was written, so the caller MUST keep its existing baseline and
    /// dirty/diff state untouched.
    case failed(message: String)
}

/// Pure save logic, isolated from AppKit so it can be unit-tested. The write
/// itself is injected so tests can exercise the success and failure paths
/// deterministically, without depending on filesystem permissions.
///
/// This exists because the editor's one job is not to lose work: the new
/// baseline must be adopted *only* when the bytes actually reached disk.
enum DocumentSaver {

    /// Persist `text` to `url`. Returns `.saved` only when the write actually
    /// succeeds; on any thrown error returns `.failed` and the caller's state
    /// must remain unchanged.
    static func save(
        _ text: String,
        to url: URL,
        using write: (String, URL) throws -> Void = { text, url in
            try text.write(to: url, atomically: true, encoding: .utf8)
        }
    ) -> SaveResult {
        do {
            try write(text, url)
            return .saved(baseline: text)
        } catch {
            return .failed(message: error.localizedDescription)
        }
    }
}
