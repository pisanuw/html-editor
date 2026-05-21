import XCTest
@testable import HTMLEditorCore

final class CustomizationAndSessionTests: XCTestCase {

    // MARK: - EditorSettings

    func testSettingsDefault() {
        let d = EditorSettings.default
        XCTAssertEqual(d.indentWidth, 2)
        XCTAssertEqual(d.fontSize, 13)
        XCTAssertEqual(d.themeName, "Default")
    }

    func testSettingsSanitizeClamps() {
        let raw = EditorSettings(indentWidth: 100, fontSize: 2, themeName: "Bogus")
        let s = raw.sanitized
        XCTAssertEqual(s.indentWidth, 8)
        XCTAssertEqual(s.fontSize, 9)
        XCTAssertEqual(s.themeName, "Default")
    }

    func testSettingsRoundTrip() {
        let s = EditorSettings(indentWidth: 4, fontSize: 15, themeName: "Midnight")
        XCTAssertEqual(EditorSettings.decoded(from: s.encoded()!), s)
    }

    func testSettingsDecodeGarbage() {
        XCTAssertNil(EditorSettings.decoded(from: Data("nope".utf8)))
    }

    // MARK: - ThemePalette

    func testHexParsing() {
        let rgb = ThemePalette.rgb(fromHex: "#ff8800")
        XCTAssertEqual(rgb?.red ?? -1, 1.0, accuracy: 0.001)
        XCTAssertEqual(rgb?.green ?? -1, 136.0 / 255.0, accuracy: 0.001)
        XCTAssertEqual(rgb?.blue ?? -1, 0.0, accuracy: 0.001)
    }

    func testHexShorthand() {
        let rgb = ThemePalette.rgb(fromHex: "#abc")
        XCTAssertEqual(rgb?.red ?? -1, 170.0 / 255.0, accuracy: 0.001)
        XCTAssertEqual(rgb?.green ?? -1, 187.0 / 255.0, accuracy: 0.001)
        XCTAssertEqual(rgb?.blue ?? -1, 204.0 / 255.0, accuracy: 0.001)
    }

    func testHexInvalid() {
        XCTAssertNil(ThemePalette.rgb(fromHex: "zzz"))
    }

    func testThemeLookup() {
        XCTAssertEqual(ThemeLibrary.palette(named: "Midnight").name, "Midnight")
        XCTAssertEqual(ThemeLibrary.palette(named: "DoesNotExist").name, "Default")
    }

    func testThemeNamesUnique() {
        let names = ThemeLibrary.all.map { $0.name }
        XCTAssertEqual(Set(names).count, names.count)
    }

    // MARK: - RecentFiles

    func testRecentDedupAndOrder() {
        var r = RecentFiles()
        r.add("a"); r.add("b"); r.add("a")
        XCTAssertEqual(r.paths, ["a", "b"])
    }

    func testRecentLimit() {
        var r = RecentFiles(limit: 2)
        r.add("a"); r.add("b"); r.add("c")
        XCTAssertEqual(r.paths, ["c", "b"])
    }

    func testRecentRoundTrip() {
        var r = RecentFiles()
        r.add("/tmp/x.html")
        XCTAssertEqual(RecentFiles.decoded(from: r.encoded()!), r)
    }

    // MARK: - SessionState

    func testSessionActiveIndexClamped() {
        let s = SessionState(tabs: [SessionTab(title: "a"), SessionTab(title: "b")], activeIndex: 9)
        XCTAssertEqual(s.safeActiveIndex, 1)
        let empty = SessionState(tabs: [], activeIndex: 3)
        XCTAssertEqual(empty.safeActiveIndex, 0)
    }

    func testSessionRoundTrip() {
        let s = SessionState(tabs: [
            SessionTab(path: "/tmp/a.html", title: "a.html"),
            SessionTab(path: nil, title: "Untitled", text: "<p>draft</p>")
        ], activeIndex: 1)
        XCTAssertEqual(SessionState.decoded(from: s.encoded()!), s)
    }

    func testSessionUntitledTextPreserved() {
        let s = SessionState(tabs: [SessionTab(title: "Untitled", text: "<h1>hi</h1>")], activeIndex: 0)
        let restored = SessionState.decoded(from: s.encoded()!)
        XCTAssertEqual(restored?.tabs.first?.text, "<h1>hi</h1>")
        XCTAssertNil(restored?.tabs.first?.path)
    }

    // MARK: - Localized range edits

    func testTabEditEmptySelection() {
        let edit = TextEditingOps.tabEdit(in: "abc", selection: NSRange(location: 1, length: 0))
        XCTAssertEqual(edit, TextEditingOps.RangeEdit(
            range: NSRange(location: 1, length: 0),
            replacement: "  ",
            selection: NSRange(location: 3, length: 0)))
    }

    func testNewlineEditAfterOpenTag() {
        let edit = TextEditingOps.newlineEdit(in: "  <div>", selection: NSRange(location: 7, length: 0))
        XCTAssertEqual(edit.range, NSRange(location: 7, length: 0))
        XCTAssertEqual(edit.replacement, "\n    ")
        XCTAssertEqual(edit.selection, NSRange(location: 12, length: 0))
    }

    func testIndentEditTouchesOnlyLineRange() {
        let edit = TextEditingOps.indentEdit(in: "x", selection: NSRange(location: 0, length: 1))
        XCTAssertEqual(edit.range, NSRange(location: 0, length: 1))
        XCTAssertEqual(edit.replacement, "  x")
    }

    func testOutdentEdit() {
        let edit = TextEditingOps.outdentEdit(in: "    x", selection: NSRange(location: 4, length: 0))
        XCTAssertEqual(edit.range, NSRange(location: 0, length: 5))
        XCTAssertEqual(edit.replacement, "  x")
        XCTAssertEqual(edit.selection, NSRange(location: 2, length: 0))
    }
}
