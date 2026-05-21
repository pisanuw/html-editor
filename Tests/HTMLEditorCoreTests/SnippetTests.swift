import XCTest
@testable import HTMLEditorCore

final class SnippetTests: XCTestCase {

    func testDefaultsAreNonEmpty() {
        XCTAssertFalse(SnippetLibrary.defaults.snippets.isEmpty)
    }

    func testEncodeDecodeRoundTrip() {
        let library = SnippetLibrary.defaults
        guard let data = library.encoded() else { return XCTFail("encoding failed") }
        let restored = SnippetLibrary.decoded(from: data)
        XCTAssertEqual(restored, library)
    }

    func testTriggerLookupCaseInsensitive() {
        let found = SnippetLibrary.defaults.snippet(forTrigger: "HTML5")
        XCTAssertEqual(found?.trigger, "html5")
    }

    func testTriggerLookupMissing() {
        XCTAssertNil(SnippetLibrary.defaults.snippet(forTrigger: "nope"))
    }

    func testDecodeGarbageReturnsNil() {
        let garbage = Data("not json".utf8)
        XCTAssertNil(SnippetLibrary.decoded(from: garbage))
    }

    func testCustomLibraryRoundTrip() {
        let lib = SnippetLibrary(snippets: [
            Snippet(name: "Lorem", trigger: "lorem", body: "Lorem ipsum")
        ])
        let data = lib.encoded()!
        XCTAssertEqual(SnippetLibrary.decoded(from: data), lib)
    }
}
