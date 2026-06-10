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

    // MARK: - offset(ofLine:in:)

    func testOffsetOfLine1IsZero() {
        XCTAssertEqual(TextMetrics.offset(ofLine: 1, in: "abc"), 0)
    }

    func testOffsetOfLine2() {
        // "a\nbc": line 2 starts at offset 2 (after the '\n').
        XCTAssertEqual(TextMetrics.offset(ofLine: 2, in: "a\nbc"), 2)
    }

    func testOffsetOfLine3() {
        XCTAssertEqual(TextMetrics.offset(ofLine: 3, in: "a\nb\nc"), 4)
    }

    func testOffsetBeyondLastLineClampsToLength() {
        let s = "abc"
        XCTAssertEqual(TextMetrics.offset(ofLine: 99, in: s), 3)
    }

    func testOffsetOfLineLessThanOneClampsToZero() {
        XCTAssertEqual(TextMetrics.offset(ofLine: 0, in: "abc"), 0)
    }

    func testOffsetRoundTripsWithLineColumn() {
        // Verify offset(ofLine:) is the inverse of lineColumn(in:at:).
        let text = "hello\nworld\nfoo"
        for line in 1...3 {
            let off = TextMetrics.offset(ofLine: line, in: text)
            XCTAssertEqual(TextMetrics.lineColumn(in: text, at: off).line, line)
        }
    }
}
