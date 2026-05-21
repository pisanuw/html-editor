import XCTest
@testable import HTMLEditorCore

final class SyntaxTokenizerTests: XCTestCase {

    private func tokens(_ text: String, ofType type: TokenType) -> [Token] {
        SyntaxTokenizer.tokenize(text).filter { $0.type == type }
    }

    func testEmptyInput() {
        XCTAssertTrue(SyntaxTokenizer.tokenize("").isEmpty)
    }

    // MARK: - HTML

    func testHTMLTagAttributeAndString() {
        let text = "<p class=\"x\">hi</p>"
        let tags = tokens(text, ofType: .tag)
        let attrs = tokens(text, ofType: .attribute)
        let strings = tokens(text, ofType: .string)

        XCTAssertEqual(tags.count, 4) // <p   >   </p   >
        XCTAssertEqual(attrs.count, 1)
        XCTAssertEqual(attrs.first?.range, NSRange(location: 3, length: 5)) // "class"
        XCTAssertEqual(strings.count, 1)
        XCTAssertEqual(strings.first?.range, NSRange(location: 9, length: 3)) // "\"x\""
    }

    func testHTMLComment() {
        let text = "<!-- hi --><p></p>"
        let comments = tokens(text, ofType: .comment)
        XCTAssertEqual(comments.count, 1)
        XCTAssertEqual(comments.first?.range, NSRange(location: 0, length: 11))
    }

    func testHTMLDoctype() {
        let text = "<!DOCTYPE html><html></html>"
        let doctype = tokens(text, ofType: .doctype)
        XCTAssertEqual(doctype.count, 1)
        XCTAssertEqual(doctype.first?.range, NSRange(location: 0, length: 15))
    }

    // MARK: - CSS

    func testEmbeddedCSS() {
        let text = "<style>body { color: red; }</style>"
        let props = tokens(text, ofType: .cssProperty)
        let values = tokens(text, ofType: .cssValue)
        let selectors = tokens(text, ofType: .cssSelector)
        let tags = tokens(text, ofType: .tag)

        XCTAssertEqual(props.count, 1)
        XCTAssertEqual(props.first?.range, NSRange(location: 14, length: 5)) // "color"
        XCTAssertEqual(values.count, 1)
        XCTAssertEqual(values.first?.range, NSRange(location: 21, length: 3)) // "red"
        XCTAssertEqual(selectors.count, 1)
        XCTAssertEqual(tags.count, 4) // <style  >  </style  >
    }

    // MARK: - JavaScript

    func testEmbeddedJavaScript() {
        let text = "<script>var x = 1; // hi</script>"
        let keywords = tokens(text, ofType: .jsKeyword)
        let comments = tokens(text, ofType: .jsComment)
        let numbers = tokens(text, ofType: .jsNumber)
        let tags = tokens(text, ofType: .tag)

        XCTAssertEqual(keywords.count, 1)
        XCTAssertEqual(keywords.first?.range, NSRange(location: 8, length: 3)) // "var"
        XCTAssertEqual(comments.count, 1)
        XCTAssertEqual(numbers.count, 1)
        XCTAssertEqual(numbers.first?.range, NSRange(location: 16, length: 1)) // "1"
        XCTAssertEqual(tags.count, 4)
    }

    func testJavaScriptIdentifierIsNotColoredAsHTMLAttribute() {
        // Regression: the `x` before `=` inside JS must NOT be tokenized as an
        // HTML attribute (the embedded region is masked from the HTML rules).
        let text = "<script>var x = 1;</script>"
        XCTAssertTrue(tokens(text, ofType: .attribute).isEmpty)
    }

    // MARK: - Ordering

    func testTokensAreSortedByLocation() {
        let text = "<style>a { color: red; }</style><p id=\"q\">hi</p>"
        let all = SyntaxTokenizer.tokenize(text)
        let locations = all.map { $0.range.location }
        XCTAssertEqual(locations, locations.sorted())
    }
}
