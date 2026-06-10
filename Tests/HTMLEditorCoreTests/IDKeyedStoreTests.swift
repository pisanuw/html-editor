import XCTest
@testable import HTMLEditorCore

final class IDKeyedStoreTests: XCTestCase {

    private class Box { let v: Int; init(_ v: Int) { self.v = v } }

    func testEmptyStoreReturnsNil() {
        var store = IDKeyedStore<Box>()
        XCTAssertNil(store.value(for: UUID()))
        XCTAssertTrue(store.isEmpty)
    }

    func testStoreAndRetrieve() {
        var store = IDKeyedStore<Box>()
        let id = UUID()
        let box = Box(42)
        store.store(box, for: id)
        XCTAssertTrue(store.value(for: id) === box)
        XCTAssertEqual(store.count, 1)
    }

    func testDiscardRemovesEntry() {
        var store = IDKeyedStore<Box>()
        let id = UUID()
        store.store(Box(1), for: id)
        store.discard(id)
        XCTAssertNil(store.value(for: id))
        XCTAssertTrue(store.isEmpty)
    }

    func testDiscardUnknownIdIsNoop() {
        var store = IDKeyedStore<Box>()
        store.discard(UUID()) // must not crash or affect other entries
        XCTAssertTrue(store.isEmpty)
    }

    func testSeparateIdsAreIndependent() {
        var store = IDKeyedStore<Box>()
        let idA = UUID(), idB = UUID()
        let boxA = Box(1), boxB = Box(2)
        store.store(boxA, for: idA)
        store.store(boxB, for: idB)
        XCTAssertTrue(store.value(for: idA) === boxA)
        XCTAssertTrue(store.value(for: idB) === boxB)
        store.discard(idA)
        XCTAssertNil(store.value(for: idA))
        XCTAssertTrue(store.value(for: idB) === boxB)
    }

    func testOverwriteReplacesValue() {
        var store = IDKeyedStore<Box>()
        let id = UUID()
        let first = Box(1), second = Box(2)
        store.store(first, for: id)
        store.store(second, for: id)
        XCTAssertTrue(store.value(for: id) === second)
        XCTAssertEqual(store.count, 1)
    }
}
