protocol Store {
    associatedtype Key: Hashable
    associatedtype Value
    func value(for key: Key) -> Value?
}

protocol CachingStore: Store {
    func cachedKeys() -> [Key]
}

protocol NamedStore: Store where Value == String {
    func names() -> [Value]
}

protocol Feed<Entry> {
    associatedtype Entry
    func latest() -> Entry?
}

protocol IntFeed: Feed<Int> {
    func total() -> Entry
}
