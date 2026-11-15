/// A protocol with an associated type and a generic subscript, which the mock's type eraser forwards to a default
/// implementation through the opened type.
protocol KeyedStore {
    associatedtype Item
    subscript<Key: Hashable>(key: Key) -> Item { get }
}

struct StringKeyedStore: KeyedStore {
    subscript<Key: Hashable>(key: Key) -> String {
        "value for \(key)"
    }
}
