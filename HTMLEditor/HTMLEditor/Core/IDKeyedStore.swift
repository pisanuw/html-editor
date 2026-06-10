import Foundation

/// A UUID-keyed weak-value store. Used by EditorCache to manage per-tab
/// objects (scroll views, folding controllers) so their lifecycle can be
/// tested without AppKit.
struct IDKeyedStore<Value: AnyObject> {
    private var values: [UUID: Value] = [:]

    func value(for id: UUID) -> Value? { values[id] }
    mutating func store(_ value: Value, for id: UUID) { values[id] = value }
    mutating func discard(_ id: UUID) { values[id] = nil }
    var isEmpty: Bool { values.isEmpty }
    var count: Int { values.count }
}
