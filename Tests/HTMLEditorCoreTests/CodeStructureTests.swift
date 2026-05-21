import XCTest
@testable import HTMLEditorCore

final class CodeStructureTests: XCTestCase {

    func testMatchingBracketFromOpen() {
        // caret just after the first '(' at index 1
        let pair = CodeStructure.matchingBracket(in: "a(b(c)d)e", caret: 2)
        XCTAssertEqual(pair?.0, NSRange(location: 1, length: 1))
        XCTAssertEqual(pair?.1, NSRange(location: 7, length: 1))
    }

    func testMatchingBracketFromClose() {
        // caret just after the outer ')' at index 7
        let pair = CodeStructure.matchingBracket(in: "a(b(c)d)e", caret: 8)
        XCTAssertEqual(pair?.0, NSRange(location: 1, length: 1))
        XCTAssertEqual(pair?.1, NSRange(location: 7, length: 1))
    }

    func testNestedBracketTypes() {
        let pair = CodeStructure.matchingBracket(in: "x[y]z", caret: 2)
        XCTAssertEqual(pair?.0, NSRange(location: 1, length: 1))
        XCTAssertEqual(pair?.1, NSRange(location: 3, length: 1))
    }

    func testNoBracketAtCaret() {
        XCTAssertNil(CodeStructure.matchingBracket(in: "abc", caret: 2))
    }

    func testUnbalancedBracket() {
        XCTAssertNil(CodeStructure.matchingBracket(in: "a(b", caret: 2))
    }

    func testFoldableRegionForMultilineTag() {
        let text = "<div>\n  <p>hi</p>\n</div>"
        let regions = CodeStructure.foldableRegions(in: text)
        XCTAssertEqual(regions, [
            CodeStructure.FoldRegion(toggleLine: 0, range: NSRange(location: 5, length: 13))
        ])
    }

    func testSingleLineTagIsNotFoldable() {
        XCTAssertTrue(CodeStructure.foldableRegions(in: "<p>hi</p>").isEmpty)
    }

    func testNestedFoldRegions() {
        // outer <ul> spans lines; inner <li> is single-line ⇒ only one region
        let text = "<ul>\n  <li>a</li>\n</ul>"
        let regions = CodeStructure.foldableRegions(in: text)
        XCTAssertEqual(regions.count, 1)
        XCTAssertEqual(regions.first?.toggleLine, 0)
    }
}
