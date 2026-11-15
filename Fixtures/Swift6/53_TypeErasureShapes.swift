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
