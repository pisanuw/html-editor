import XCTest
@testable import HTMLEditorCore

final class FindEngineTests: XCTestCase {

    // MARK: - matches

    func testMatchesFindsAllNonOverlapping() {
        let ranges = FindEngine.matches(in: "abcabc", query: "abc")
        XCTAssertEqual(ranges, [NSRange(location: 0, length: 3),
                                NSRange(location: 3, length: 3)])
    }

    func testMatchesIsNonOverlapping() {
        // "aa" in "aaa" matches once at the start; the engine then resumes past it.
        let ranges = FindEngine.matches(in: "aaa", query: "aa")
        XCTAssertEqual(ranges, [NSRange(location: 0, length: 2)])
    }

    func testMatchesCaseInsensitiveByDefault() {
        let ranges = FindEngine.matches(in: "Hello hello", query: "hello")
        XCTAssertEqual(ranges.count, 2)
    }

    func testMatchesCaseSensitive() {
        let ranges = FindEngine.matches(in: "Hello hello", query: "hello",
                                        options: FindOptions(caseSensitive: true))
        XCTAssertEqual(ranges, [NSRange(location: 6, length: 5)])
    }

    func testMatchesWholeWord() {
        let ranges = FindEngine.matches(in: "cat category", query: "cat",
                                        options: FindOptions(wholeWord: true))
        XCTAssertEqual(ranges, [NSRange(location: 0, length: 3)])
    }

    func testMatchesRegex() {
        let ranges = FindEngine.matches(in: "a1b2c3", query: "\\d",
                                        options: FindOptions(useRegex: true))
        XCTAssertEqual(ranges.count, 3)
    }

    func testMatchesEmptyQueryReturnsNothing() {
        XCTAssertTrue(FindEngine.matches(in: "abc", query: "").isEmpty)
    }

    func testMatchesInvalidRegexReturnsNothing() {
        let ranges = FindEngine.matches(in: "abc", query: "[",
                                        options: FindOptions(useRegex: true))
        XCTAssertTrue(ranges.isEmpty)
    }

    func testMatchesLiteralSpecialCharsAreEscaped() {
        // In literal (non-regex) mode "." matches only a real dot, not any char.
        let ranges = FindEngine.matches(in: "a.b.c", query: ".")
        XCTAssertEqual(ranges, [NSRange(location: 1, length: 1),
                                NSRange(location: 3, length: 1)])
    }

    // MARK: - replaceAll

    func testReplaceAllLiteral() {
        let result = FindEngine.replaceAll(in: "abcabc", query: "abc", replacement: "X")
        XCTAssertEqual(result.text, "XX")
        XCTAssertEqual(result.count, 2)
    }

    func testReplaceAllLiteralTreatsQueryLiterally() {
        let result = FindEngine.replaceAll(in: "a.b.c", query: ".", replacement: "-")
        XCTAssertEqual(result.text, "a-b-c")
        XCTAssertEqual(result.count, 2)
    }

    func testReplaceAllLiteralReplacementDollarsNotTreatedAsTemplate() {
        // In literal mode a "$1" replacement is inserted verbatim.
        let result = FindEngine.replaceAll(in: "ab", query: "a", replacement: "$1")
        XCTAssertEqual(result.text, "$1b")
        XCTAssertEqual(result.count, 1)
    }

    func testReplaceAllRegexTemplate() {
        let result = FindEngine.replaceAll(in: "John Smith",
                                           query: "(\\w+) (\\w+)",
                                           replacement: "$2 $1",
                                           options: FindOptions(useRegex: true))
        XCTAssertEqual(result.text, "Smith John")
        XCTAssertEqual(result.count, 1)
    }

    func testReplaceAllNoMatchReturnsOriginal() {
        let result = FindEngine.replaceAll(in: "abc", query: "z", replacement: "Q")
        XCTAssertEqual(result.text, "abc")
        XCTAssertEqual(result.count, 0)
    }

    // MARK: - step

    func testStepFromNilForwardIsFirst() {
        XCTAssertEqual(FindEngine.step(from: nil, total: 3, forward: true), 0)
    }

    func testStepFromNilBackwardIsLast() {
        XCTAssertEqual(FindEngine.step(from: nil, total: 3, forward: false), 2)
    }

    func testStepForwardWraps() {
        XCTAssertEqual(FindEngine.step(from: 2, total: 3, forward: true), 0)
    }

    func testStepBackwardWraps() {
        XCTAssertEqual(FindEngine.step(from: 0, total: 3, forward: false), 2)
    }

    func testStepForwardNormal() {
        XCTAssertEqual(FindEngine.step(from: 1, total: 3, forward: true), 2)
    }

    func testStepEmptyReturnsNil() {
        XCTAssertNil(FindEngine.step(from: nil, total: 0, forward: true))
    }

    // MARK: - firstMatchIndex

    func testFirstMatchIndexAtOrAfter() {
        let ranges = [NSRange(location: 0, length: 3), NSRange(location: 5, length: 3)]
        XCTAssertEqual(FindEngine.firstMatchIndex(in: ranges, atOrAfter: 1), 1)
    }

    func testFirstMatchIndexExactBoundary() {
        let ranges = [NSRange(location: 0, length: 3), NSRange(location: 5, length: 3)]
        XCTAssertEqual(FindEngine.firstMatchIndex(in: ranges, atOrAfter: 0), 0)
    }

    func testFirstMatchIndexFallsBackToFirst() {
        let ranges = [NSRange(location: 0, length: 3)]
        XCTAssertEqual(FindEngine.firstMatchIndex(in: ranges, atOrAfter: 100), 0)
    }

    func testFirstMatchIndexEmptyReturnsNil() {
        XCTAssertNil(FindEngine.firstMatchIndex(in: [], atOrAfter: 0))
    }
}
