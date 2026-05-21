import XCTest
@testable import HTMLEditorCore

final class TextEditingOpsTests: XCTestCase {

    // MARK: - insertTab (empty selection)

    func testInsertTabAtStartInsertsIndentUnit() {
        let result = TextEditingOps.insertTab(in: "abc", selection: NSRange(location: 0, length: 0))
        XCTAssertEqual(result.text, "  abc")
        XCTAssertEqual(result.selection, NSRange(location: 2, length: 0))
    }

    func testInsertTabAtEnd() {
        let result = TextEditingOps.insertTab(in: "abc", selection: NSRange(location: 3, length: 0))
        XCTAssertEqual(result.text, "abc  ")
        XCTAssertEqual(result.selection, NSRange(location: 5, length: 0))
    }

    func testInsertTabCustomWidth() {
        let result = TextEditingOps.insertTab(in: "x", selection: NSRange(location: 0, length: 0),
                                              indentWidth: 4)
        XCTAssertEqual(result.text, "    x")
        XCTAssertEqual(result.selection, NSRange(location: 4, length: 0))
    }

    // MARK: - insertTab (non-empty selection -> block indent)

    func testInsertTabWithSelectionIndentsLines() {
        let result = TextEditingOps.insertTab(in: "a\nb", selection: NSRange(location: 0, length: 3))
        XCTAssertEqual(result.text, "  a\n  b")
    }

    // MARK: - indentLines

    func testIndentLinesBothLines() {
        let result = TextEditingOps.indentLines(in: "a\nb", selection: NSRange(location: 0, length: 3))
        XCTAssertEqual(result.text, "  a\n  b")
        XCTAssertEqual(result.selection, NSRange(location: 2, length: 5))
    }

    func testIndentLinesSkipsBlankLine() {
        // The empty middle line should not be padded.
        let result = TextEditingOps.indentLines(in: "a\n\nb", selection: NSRange(location: 0, length: 4))
        XCTAssertEqual(result.text, "  a\n\n  b")
    }

    func testIndentLinesPartialSelectionStillIndentsWholeLine() {
        // Selection touching only the middle of a single line indents that line.
        let result = TextEditingOps.indentLines(in: "hello", selection: NSRange(location: 2, length: 1))
        XCTAssertEqual(result.text, "  hello")
    }

    // MARK: - outdentLines

    func testOutdentLinesRemovesOneUnit() {
        let result = TextEditingOps.outdentLines(in: "    a\n  b",
                                                 selection: NSRange(location: 0, length: 9))
        XCTAssertEqual(result.text, "  a\nb")
    }

    func testOutdentLinesPartialIndentRemovesWhatExists() {
        let result = TextEditingOps.outdentLines(in: " a", selection: NSRange(location: 0, length: 0))
        XCTAssertEqual(result.text, "a")
    }

    func testOutdentTabCountsAsOneCharacter() {
        let result = TextEditingOps.outdentLines(in: "\tab", selection: NSRange(location: 0, length: 0))
        XCTAssertEqual(result.text, "ab")
    }

    func testOutdentNoLeadingWhitespaceIsNoOp() {
        let result = TextEditingOps.outdentLines(in: "abc", selection: NSRange(location: 0, length: 0))
        XCTAssertEqual(result.text, "abc")
    }

    // MARK: - insertNewline (smart indent)

    func testNewlinePreservesLeadingWhitespace() {
        let result = TextEditingOps.insertNewline(in: "    text", selection: NSRange(location: 8, length: 0))
        XCTAssertEqual(result.text, "    text\n    ")
        XCTAssertEqual(result.selection, NSRange(location: 13, length: 0))
    }

    func testNewlineAfterOpeningTagAddsIndent() {
        let result = TextEditingOps.insertNewline(in: "  <div>", selection: NSRange(location: 7, length: 0))
        XCTAssertEqual(result.text, "  <div>\n    ")
        XCTAssertEqual(result.selection, NSRange(location: 12, length: 0))
    }

    func testNewlineAfterOpeningBraceAddsIndent() {
        let result = TextEditingOps.insertNewline(in: "foo {", selection: NSRange(location: 5, length: 0))
        XCTAssertEqual(result.text, "foo {\n  ")
    }

    func testNewlineAfterClosingTagDoesNotAddIndent() {
        let result = TextEditingOps.insertNewline(in: "  </div>", selection: NSRange(location: 8, length: 0))
        XCTAssertEqual(result.text, "  </div>\n  ")
    }

    func testNewlineAfterSelfClosingTagDoesNotAddIndent() {
        let result = TextEditingOps.insertNewline(in: "<br/>", selection: NSRange(location: 5, length: 0))
        XCTAssertEqual(result.text, "<br/>\n")
    }

    func testNewlineAfterPlainTextDoesNotAddIndent() {
        let result = TextEditingOps.insertNewline(in: "hello", selection: NSRange(location: 5, length: 0))
        XCTAssertEqual(result.text, "hello\n")
    }
}
