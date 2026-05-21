import XCTest
@testable import HTMLEditorCore

final class TextMetricsTests: XCTestCase {

    func testLineColumnAtStart() {
        let result = TextMetrics.lineColumn(in: "abc", at: 0)
        XCTAssertEqual(result.line, 1)
        XCTAssertEqual(result.column, 1)
    }

    func testLineColumnMidFirstLine() {
        let result = TextMetrics.lineColumn(in: "abc", at: 2)
        XCTAssertEqual(result.line, 1)
        XCTAssertEqual(result.column, 3)
    }

    func testLineColumnOnSecondLine() {
        // "a\nbc", offset 3 sits at the 'c' on line 2, column 2.
        let result = TextMetrics.lineColumn(in: "a\nbc", at: 3)
        XCTAssertEqual(result.line, 2)
        XCTAssertEqual(result.column, 2)
    }

    func testLineColumnAtNewlineBoundary() {
        // Offset 2 is the start of line 2 (just past the '\n').
        let result = TextMetrics.lineColumn(in: "a\nbc", at: 2)
        XCTAssertEqual(result.line, 2)
        XCTAssertEqual(result.column, 1)
    }

    func testLineColumnClampsOutOfRange() {
        let result = TextMetrics.lineColumn(in: "abc", at: 100)
        XCTAssertEqual(result.line, 1)
        XCTAssertEqual(result.column, 4) // clamped to end (length 3) + 1
    }

    func testLineColumnClampsNegative() {
        let result = TextMetrics.lineColumn(in: "abc", at: -5)
        XCTAssertEqual(result.line, 1)
        XCTAssertEqual(result.column, 1)
    }

    func testLineCountEmptyStringIsOne() {
        XCTAssertEqual(TextMetrics.lineCount(in: ""), 1)
    }

    func testLineCountSingleLine() {
        XCTAssertEqual(TextMetrics.lineCount(in: "hello"), 1)
    }

    func testLineCountMultipleLines() {
        XCTAssertEqual(TextMetrics.lineCount(in: "a\nb\nc"), 3)
    }

    func testLineCountTrailingNewlineCountsFinalLine() {
        XCTAssertEqual(TextMetrics.lineCount(in: "a\nb\n"), 3)
    }
}
