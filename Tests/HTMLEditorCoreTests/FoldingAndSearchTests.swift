import XCTest
@testable import HTMLEditorCore

final class FoldingAndSearchTests: XCTestCase {

    // MARK: - FoldingModel

    func testFoldableToggleLines() {
        let text = "<div>\n  <p>hi</p>\n</div>"
        XCTAssertEqual(FoldingModel.foldableToggleLines(in: text), [0])
    }

    func testHiddenRangesWhenFolded() {
        let text = "<div>\n  <p>hi</p>\n</div>"
        // The single foldable region is on toggle line 0; folding it hides its
        // inner range (the content between <div> and </div>).
        let hidden = FoldingModel.hiddenRanges(in: text, foldedToggleLines: [0])
        XCTAssertEqual(hidden, [NSRange(location: 5, length: 13)])
    }

    func testNothingHiddenWhenNotFolded() {
        let text = "<div>\n  <p>hi</p>\n</div>"
        XCTAssertTrue(FoldingModel.hiddenRanges(in: text, foldedToggleLines: []).isEmpty)
    }

    func testMergeOverlappingRanges() {
        let merged = FoldingModel.merge([
            NSRange(location: 0, length: 5),
            NSRange(location: 4, length: 5),
            NSRange(location: 20, length: 2)
        ])
        XCTAssertEqual(merged, [NSRange(location: 0, length: 9), NSRange(location: 20, length: 2)])
    }

    // MARK: - MultiFileSearch

    func testSearchHitsWithLineNumbers() {
        let text = "<h1>Title</h1>\n<p>find me</p>\n<p>find again</p>"
        let hits = MultiFileSearch.hits(in: text, query: "find")
        XCTAssertEqual(hits.count, 2)
        XCTAssertEqual(hits[0].line, 2)
        XCTAssertEqual(hits[0].lineText, "<p>find me</p>")
        XCTAssertEqual(hits[1].line, 3)
    }

    func testSearchNoHits() {
        XCTAssertTrue(MultiFileSearch.hits(in: "<p>nothing</p>", query: "zzz").isEmpty)
    }

    func testSearchCaseInsensitiveByDefault() {
        let hits = MultiFileSearch.hits(in: "<p>Hello</p>", query: "hello")
        XCTAssertEqual(hits.count, 1)
    }

    // MARK: - PreviewWidth

    func testPreviewWidthPoints() {
        XCTAssertNil(PreviewWidth.responsive.points)
        XCTAssertEqual(PreviewWidth.phone.points, 390)
        XCTAssertEqual(PreviewWidth.tablet.points, 768)
        XCTAssertEqual(PreviewWidth.desktop.points, 1024)
    }

    func testPreviewWidthAllCases() {
        XCTAssertEqual(PreviewWidth.allCases.count, 4)
    }
}
