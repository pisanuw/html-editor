import XCTest
@testable import HTMLEditorCore

final class HTMLCompletionTests: XCTestCase {

    func testTagNameContext() {
        let ctx = HTMLCompletion.context(in: "<di", caret: 3)
        XCTAssertEqual(ctx, .tagName(prefix: "di", replace: NSRange(location: 1, length: 2)))
    }

    func testAttributeContextEmptyPrefix() {
        let ctx = HTMLCompletion.context(in: "<div ", caret: 5)
        XCTAssertEqual(ctx, .attributeName(prefix: "", replace: NSRange(location: 5, length: 0)))
    }

    func testAttributeContextWithPrefix() {
        let ctx = HTMLCompletion.context(in: "<div cl", caret: 7)
        XCTAssertEqual(ctx, .attributeName(prefix: "cl", replace: NSRange(location: 5, length: 2)))
    }

    func testNoCompletionInAttributeValue() {
        XCTAssertEqual(HTMLCompletion.context(in: "<div class=", caret: 11), .none)
    }

    func testNoCompletionInTextContent() {
        XCTAssertEqual(HTMLCompletion.context(in: "<p>he", caret: 5), .none)
    }

    func testNoCompletionForClosingTag() {
        XCTAssertEqual(HTMLCompletion.context(in: "</di", caret: 4), .none)
    }

    func testTagCompletionsExact() {
        XCTAssertEqual(HTMLCompletion.tagCompletions(prefix: "div"), ["div"])
    }

    func testTagCompletionsMultiple() {
        let hits = HTMLCompletion.tagCompletions(prefix: "h")
        XCTAssertTrue(hits.contains("h1"))
        XCTAssertTrue(hits.contains("head"))
        XCTAssertEqual(hits, hits.sorted())
    }

    func testAttributeCompletionsExact() {
        XCTAssertEqual(HTMLCompletion.attributeCompletions(prefix: "cl"), ["class"])
    }

    func testAttributeCompletionsData() {
        XCTAssertTrue(HTMLCompletion.attributeCompletions(prefix: "data").contains("data-"))
    }
}
