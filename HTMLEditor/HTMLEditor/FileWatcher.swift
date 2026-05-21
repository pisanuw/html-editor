import Foundation

/// Watches a single file for external modifications using a dispatch source.
/// Fires `onChange` on the main queue when the file is written, renamed,
/// extended, or deleted.
final class FileWatcher {
    private var source: DispatchSourceFileSystemObject?
    private var descriptor: Int32 = -1

    var onChange: (() -> Void)?

    func watch(_ url: URL) {
        stop()
        descriptor = open(url.path, O_EVTONLY)
        guard descriptor >= 0 else { return }

        let src = DispatchSource.makeFileSystemObjectSource(
            fileDescriptor: descriptor,
            eventMask: [.write, .rename, .delete, .extend],
            queue: .main)
        src.setEventHandler { [weak self] in self?.onChange?() }
        src.setCancelHandler { [weak self] in
            if let fd = self?.descriptor, fd >= 0 { close(fd) }
            self?.descriptor = -1
        }
        source = src
        src.resume()
    }

    func stop() {
        source?.cancel()
        source = nil
    }

    deinit { stop() }
}
