import XCTest
@testable import HTMLEditorCore

final class TagEditingTests: XCTestCase {

    // MARK: - Auto-close

    func testAutoCloseSimpleTag() {
        let result = TagEditing.autoClose(in: "<div>", caretAfterBracket: 5)
        XCTAssertEqual(result, TagEditing.CloseResult(closing: "</div>", caret: 5))
    }

    func testAutoCloseWithAttributes() {
        let text = #"<a href="#">"#                 // length 12
        let result = TagEditing.autoClose(in: text, caretAfterBracket: (text as NSString).length)
        XCTAssertEqual(result?.closing, "</a>")
    }

    func testNoAutoCloseForVoidElement() {
        XCTAssertNil(TagEditing.autoClose(in: "<br>", caretAfterBracket: 4))
        XCTAssertNil(TagEditing.autoClose(in: "<img>", caretAfterBracket: 5))
    }

    func testNoAutoCloseForClosingTag() {
        XCTAssertNil(TagEditing.autoClose(in: "</div>", caretAfterBracket: 6))
    }

    func testNoAutoCloseForSelfClosing() {
        XCTAssertNil(TagEditing.autoClose(in: "<img/>", caretAfterBracket: 6))
    }

    func testNoAutoCloseWhenAlreadyClosed() {
        // caret right after the first '>' of "<div></div>"
        XCTAssertNil(TagEditing.autoClose(in: "<div></div>", caretAfterBracket: 5))
    }

    func testNoAutoCloseWhenCaretNotAfterBracket() {
        XCTAssertNil(TagEditing.autoClose(in: "<div", caretAfterBracket: 4))
    }

    // MARK: - Matching tag ranges

    func testMatchingOpenToClose() {
        let text = "<div><span></span></div>"
        let ranges = TagEditing.matchingTagNameRanges(in: text, caret: 2) // inside <div>
        XCTAssertEqual(ranges?.0, NSRange(location: 1, length: 3))  // "div" open
        XCTAssertEqual(ranges?.1, NSRange(location: 20, length: 3)) // "div" close
    }

    func testMatchingInnerPair() {
        let text = "<div><span></span></div>"
        let ranges = TagEditing.matchingTagNameRanges(in: text, caret: 7) // inside <span>
        XCTAssertEqual(ranges?.0, NSRange(location: 6, length: 4))  // "span" open
        XCTAssertEqual(ranges?.1, NSRange(location: 13, length: 4)) // "span" close
    }

    func testMatchingFromClosingTag() {
        let text = "<div><span></span></div>"
        let ranges = TagEditing.matchingTagNameRanges(in: text, caret: 21) // inside </div>
        XCTAssertEqual(ranges?.0, NSRange(location: 1, length: 3))
        XCTAssertEqual(ranges?.1, NSRange(location: 20, length: 3))
    }

    func testMatchingNestedSameName() {
        let text = "<div><div></div></div>"
        let ranges = TagEditing.matchingTagNameRanges(in: text, caret: 2) // outer open
        XCTAssertEqual(ranges?.0, NSRange(location: 1, length: 3))
        XCTAssertEqual(ranges?.1, NSRange(location: 18, length: 3)) // outer close
    }

    func testSelfClosingHasNoMatch() {
        XCTAssertNil(TagEditing.matchingTagNameRanges(in: "<br/>", caret: 2))
    }

    func testScanIgnoresComments() {
        let tokens = TagEditing.scanTags("<!-- <div> --><p></p>")
        XCTAssertEqual(tokens.map { $0.name }, ["p", "p"])
    }
}
