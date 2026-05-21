import XCTest
@testable import HTMLEditorCore

final class HTMLFormatterTests: XCTestCase {

    func testNestedElementsAreIndented() {
        let result = HTMLFormatter.prettify("<div><p>Hi</p></div>")
        XCTAssertEqual(result, "<div>\n  <p>\n    Hi\n  </p>\n</div>")
    }

    func testCustomIndentWidth() {
        let result = HTMLFormatter.prettify("<div><p>Hi</p></div>", indentWidth: 4)
        XCTAssertEqual(result, "<div>\n    <p>\n        Hi\n    </p>\n</div>")
    }

    func testVoidElementDoesNotIncreaseDepth() {
        let result = HTMLFormatter.prettify("<div><br><span>x</span></div>")
        XCTAssertEqual(result, "<div>\n  <br>\n  <span>\n    x\n  </span>\n</div>")
    }

    func testSelfClosingTagDoesNotIncreaseDepth() {
        let result = HTMLFormatter.prettify("<div><img src=\"a.png\"/><p>x</p></div>")
        XCTAssertEqual(result,
            "<div>\n  <img src=\"a.png\"/>\n  <p>\n    x\n  </p>\n</div>")
    }

    func testDoctypeIsEmittedOnOwnLine() {
        let result = HTMLFormatter.prettify("<!DOCTYPE html><html></html>")
        XCTAssertEqual(result, "<!DOCTYPE html>\n<html>\n</html>")
    }

    func testCommentIsPreserved() {
        let result = HTMLFormatter.prettify("<div><!-- note --><p>x</p></div>")
        XCTAssertEqual(result,
            "<div>\n  <!-- note -->\n  <p>\n    x\n  </p>\n</div>")
    }

    func testPreContentIsKeptVerbatim() {
        // Significant whitespace inside <pre> must survive untouched.
        let result = HTMLFormatter.prettify("<pre>  x\n  y</pre>")
        XCTAssertEqual(result, "<pre>  x\n  y</pre>")
    }

    func testScriptContentIsReindented() {
        let result = HTMLFormatter.prettify("<script>\nvar x = 1;\n</script>")
        XCTAssertEqual(result, "<script>\n  var x = 1;\n</script>")
    }

    func testCollapsesInsignificantWhitespaceInText() {
        let result = HTMLFormatter.prettify("<p>hello    world</p>")
        XCTAssertEqual(result, "<p>\n  hello world\n</p>")
    }

    func testQuotedAngleBracketsInAttributesDoNotBreakTag() {
        // The '>' inside the attribute value must not be treated as the tag end.
        let result = HTMLFormatter.prettify("<a title=\"a > b\">x</a>")
        XCTAssertEqual(result, "<a title=\"a > b\">\n  x\n</a>")
    }
}
