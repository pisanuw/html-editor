import XCTest
@testable import HTMLEditorCore

final class HTMLToMarkdownTests: XCTestCase {

    private func md(_ html: String) -> String { HTMLToMarkdown.convert(html) }

    func testHeading() {
        XCTAssertEqual(md("<h1>Hello</h1>"), "# Hello")
        XCTAssertEqual(md("<h3>Sub</h3>"), "### Sub")
    }

    func testParagraphWithInlineEmphasis() {
        XCTAssertEqual(md("<p>Hello <strong>world</strong></p>"), "Hello **world**")
        XCTAssertEqual(md("<p>Say <em>hi</em> now</p>"), "Say *hi* now")
    }

    func testLink() {
        XCTAssertEqual(md(#"<a href="https://x.com">link</a>"#), "[link](https://x.com)")
    }

    func testImage() {
        XCTAssertEqual(md(#"<img src="a.png" alt="Cat">"#), "![Cat](a.png)")
    }

    func testInlineCode() {
        XCTAssertEqual(md("<p>Use <code>x = 1</code> here</p>"), "Use `x = 1` here")
    }

    func testUnorderedList() {
        XCTAssertEqual(md("<ul><li>One</li><li>Two</li></ul>"), "- One\n- Two")
    }

    func testOrderedList() {
        XCTAssertEqual(md("<ol><li>First</li><li>Second</li></ol>"), "1. First\n2. Second")
    }

    func testNestedList() {
        XCTAssertEqual(md("<ul><li>A<ul><li>B</li></ul></li></ul>"), "- A\n  - B")
    }

    func testHeadingThenParagraph() {
        XCTAssertEqual(md("<h2>Title</h2><p>Body text here.</p>"), "## Title\n\nBody text here.")
    }

    func testEntitiesDecoded() {
        XCTAssertEqual(md("<p>a &amp; b &lt;tag&gt;</p>"), "a & b <tag>")
    }

    func testHorizontalRule() {
        XCTAssertEqual(md("<hr>"), "---")
    }

    func testBlockquote() {
        XCTAssertEqual(md("<blockquote><p>Quote</p></blockquote>"), "> Quote")
    }

    func testWhitespaceCollapsedInParagraph() {
        XCTAssertEqual(md("<p>lots   of\n   space</p>"), "lots of space")
    }

    func testIgnoresComments() {
        XCTAssertEqual(md("<!-- hi --><p>x</p>"), "x")
    }
}
