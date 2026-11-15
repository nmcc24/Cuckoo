// Associated types declared under `#if`. The mock takes them all as generic parameters, and its generic
// default-implementation entry points constrain each only in the build where it's declared. The matrix compiles
// this fixture with and without `DEBUG`.
protocol DebugFeed {
    #if DEBUG
    associatedtype Item
    func next() -> Item
    #else
    func next() -> Int
    #endif
}

protocol EitherFeed {
    associatedtype Key
    #if DEBUG
    associatedtype Value
    func value(for key: Key) -> Value
    #elseif os(Linux)
    func value(for key: Key) -> String
    #else
    func value(for key: Key) -> Int
    #endif
}

#if DEBUG
func useDebugFeed(_ feed: MockDebugFeed<String>) -> String {
    feed.next()
}
#endif
