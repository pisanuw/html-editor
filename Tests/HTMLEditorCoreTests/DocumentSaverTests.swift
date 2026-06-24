import XCTest
@testable import HTMLEditorCore

final class DocumentSaverTests: XCTestCase {

    func testSuccessfulWriteReportsNewBaselineAndPersistsBytes() throws {
        let dir = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString, isDirectory: true)
        try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: dir) }
        let url = dir.appendingPathComponent("page.html")

        let result = DocumentSaver.save("<h1>hi</h1>", to: url)

        XCTAssertEqual(result, .saved(baseline: "<h1>hi</h1>"))
        XCTAssertEqual(try String(contentsOf: url, encoding: .utf8), "<h1>hi</h1>")
    }

    func testUnwritableURLReportsFailureAndWritesNothing() {
        // The parent directory does not exist, so the write must throw. This is
        // the regression guard for the silent data-loss bug: a failed write must
        // never be reported as success.
        let url = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString, isDirectory: true)
            .appendingPathComponent("page.html")

        let result = DocumentSaver.save("<h1>hi</h1>", to: url)

        guard case .failed = result else {
            return XCTFail("Expected .failed for an unwritable URL, got \(result)")
        }
        XCTAssertFalse(FileManager.default.fileExists(atPath: url.path))
    }

    func testInjectedWriterErrorIsReportedAsFailure() {
        struct DiskFull: Error {}
        let url = FileManager.default.temporaryDirectory.appendingPathComponent("x.html")

        let result = DocumentSaver.save("data", to: url) { _, _ in throw DiskFull() }

        guard case .failed = result else {
            return XCTFail("Expected .failed when the underlying write throws")
        }
    }
}
