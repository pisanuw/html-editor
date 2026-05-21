import XCTest
@testable import HTMLEditorCore

final class HTMLExporterTests: XCTestCase {

    // MARK: - minify

    func testMinifyStripsCommentsAndCollapsesWhitespace() {
        let result = HTMLExporter.minify("<!-- c --><div>  <p>Hi</p>  </div>")
        XCTAssertEqual(result, "<div><p>Hi</p></div>")
    }

    func testMinifyPreservesPreContents() {
        let result = HTMLExporter.minify("<pre>  x  y</pre>")
        XCTAssertEqual(result, "<pre>  x  y</pre>")
    }

    func testMinifyPreservesScriptContents() {
        // The double space inside the script body is significant and kept.
        let result = HTMLExporter.minify("<script>var a =  1;</script>")
        XCTAssertEqual(result, "<script>var a =  1;</script>")
    }

    func testMinifyCollapsesTextWhitespaceToSingleSpace() {
        let result = HTMLExporter.minify("<p>hello     world</p>")
        XCTAssertEqual(result, "<p>hello world</p>")
    }

    // MARK: - standaloneDocument

    func testStandaloneWrapsFragment() {
        let result = HTMLExporter.standaloneDocument("<p>Hi</p>", title: "My Title")
        XCTAssertTrue(result.hasPrefix("<!DOCTYPE html>"))
        XCTAssertTrue(result.contains("<title>My Title</title>"))
        XCTAssertTrue(result.contains("<p>Hi</p>"))
    }

    func testStandaloneAddsDoctypeToExistingHtmlRoot() {
        let result = HTMLExporter.standaloneDocument("<html><body></body></html>")
        XCTAssertTrue(result.hasPrefix("<!DOCTYPE html>\n"))
        XCTAssertTrue(result.contains("<html><body></body></html>"))
    }

    func testStandaloneLeavesCompleteDocumentUnchanged() {
        let doc = "<!DOCTYPE html>\n<html><body>x</body></html>"
        XCTAssertEqual(HTMLExporter.standaloneDocument(doc), doc)
    }

    func testStandaloneEscapesTitle() {
        let result = HTMLExporter.standaloneDocument("<p>x</p>", title: "A < B & C")
        XCTAssertTrue(result.contains("<title>A &lt; B &amp; C</title>"))
    }

    // MARK: - bodyFragment

    func testBodyFragmentExtractsInnerBody() {
        let result = HTMLExporter.bodyFragment("<html><body><p>Hi</p></body></html>")
        XCTAssertEqual(result, "<p>Hi</p>")
    }

    func testBodyFragmentWithoutBodyReturnsTrimmedInput() {
        let result = HTMLExporter.bodyFragment("  <p>Hi</p>  ")
        XCTAssertEqual(result, "<p>Hi</p>")
    }

    // MARK: - suggestedFilename

    func testSuggestedFilenameFromTitle() {
        XCTAssertEqual(HTMLExporter.suggestedFilename(for: "<title>My Page</title>"),
                       "my-page.html")
    }

    func testSuggestedFilenameFallsBackToIndex() {
        XCTAssertEqual(HTMLExporter.suggestedFilename(for: "<p>no title here</p>"),
                       "index.html")
    }

    func testSuggestedFilenameSlugifiesPunctuation() {
        XCTAssertEqual(HTMLExporter.suggestedFilename(for: "<title>Hello, World!</title>"),
                       "hello-world.html")
    }
}
