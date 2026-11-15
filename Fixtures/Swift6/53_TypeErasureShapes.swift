// Protocols with associated types whose mocks erase the default implementation's type: an actor protocol, whose
// mock refuses a default implementation and needs no eraser; a static method returning nothing; and generic
// subscripts naming the associated type, which the eraser forwards through the opened default implementation.
protocol ItemActor: Actor {
    associatedtype Item
    func item() -> Item
}

protocol StaticResetting {
    associatedtype Value
    func value() -> Value
    static func reset()
}

protocol KeyedItems {
    associatedtype Item
    subscript<Key: Hashable>(key: Key) -> Item { get set }
    subscript<Key: Hashable>(lookup key: Key) -> Item? { get }
}

protocol ThrowingKeyedItems {
    associatedtype Item
    subscript<Key: Hashable>(key: Key) -> Item { get async throws }
}

// A generic member whose `where` clause names an associated type can't be forwarded to an opened default
// implementation, whose associated types Swift can't relate to the mock's: the mock compiles, and a default
// implementation stops with a message saying to stub it.
protocol KeyedCounter {
    associatedtype Key
    func count<Keys: Collection>(_ keys: Keys) -> Int where Keys.Element == Key
    subscript<Keys: Collection>(keys keys: Keys) -> Int where Keys.Element == Key { get }
}
