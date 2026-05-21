import XCTest
@testable import HTMLEditorCore

final class MultiCursorTests: XCTestCase {

    func testNextOccurrenceForward() {
        let r = MultiCursor.nextOccurrence(of: "ab", in: "abXab", after: 1)
        XCTAssertEqual(r, NSRange(location: 3, length: 2))
    }

    func testNextOccurrenceWraps() {
        let r = MultiCursor.nextOccurrence(of: "ab", in: "abXab", after: 4)
        XCTAssertEqual(r, NSRange(location: 0, length: 2))
    }

    func testNextOccurrenceMissing() {
        XCTAssertNil(MultiCursor.nextOccurrence(of: "zz", in: "abXab", after: 0))
    }

    func testAddingNextOccurrence() {
        let ranges = MultiCursor.addingNextOccurrence(of: "x", in: "x x x", existing: [NSRange(location: 0, length: 1)])
        XCTAssertEqual(ranges, [NSRange(location: 0, length: 1), NSRange(location: 2, length: 1)])
    }

    func testAddingNextOccurrenceSkipsSelected() {
        // 0 and 2 already selected ⇒ next new one is at 4
        let existing = [NSRange(location: 0, length: 1), NSRange(location: 2, length: 1)]
        let ranges = MultiCursor.addingNextOccurrence(of: "x", in: "x x x", existing: existing)
        XCTAssertEqual(ranges?.last, NSRange(location: 4, length: 1))
    }

    func testSplitIntoLines() {
        let carets = MultiCursor.splitIntoLines(selection: NSRange(location: 0, length: 5), in: "a\nb\nc")
        XCTAssertEqual(carets, [
            NSRange(location: 1, length: 0),
            NSRange(location: 3, length: 0),
            NSRange(location: 5, length: 0)
        ])
    }

    func testColumnCarets() {
        // caret column 1 on each of three lines
        let text = "abc\ndef\nghi"
        let ranges = MultiCursor.columnSelections(for: NSRange(location: 1, length: 8), in: text)
        XCTAssertEqual(ranges, [
            NSRange(location: 1, length: 0),
            NSRange(location: 5, length: 0),
            NSRange(location: 9, length: 0)
        ])
    }

    func testColumnBlockSelection() {
        // columns 1..3 on two lines selects "bc" and "fg"
        let text = "abcd\nefgh"
        let ranges = MultiCursor.columnSelections(for: NSRange(location: 1, length: 7), in: text)
        XCTAssertEqual(ranges, [
            NSRange(location: 1, length: 2),
            NSRange(location: 6, length: 2)
        ])
    }
}
