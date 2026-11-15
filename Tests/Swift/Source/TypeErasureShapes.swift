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

/// A settable generic subscript, whose setter reaches a value-type default implementation and stays set.
protocol MutableKeyedStore {
    associatedtype Item
    subscript<Key: Hashable>(key: Key) -> Item? { get set }
}

struct DictionaryKeyedStore: MutableKeyedStore {
    var values: [AnyHashable: String] = [:]

    subscript<Key: Hashable>(key: Key) -> String? {
        get { values[key] }
        set { values[key] = newValue }
    }
}

/// Members the type eraser forwards with their effects, and one it can't forward: an `inout` argument.
protocol EffectfulStore {
    associatedtype Item
    var latest: Item { get async throws }
    func adjust(_ item: inout Item)
}

struct IntEffectfulStore: EffectfulStore {
    var latest: Int {
        get async throws { 42 }
    }

    func adjust(_ item: inout Int) {
        item += 1
    }
}
