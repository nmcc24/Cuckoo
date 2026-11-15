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

// Associated types under two independent conditions: the entry points have a branch for each combination, so a
// build with only `DEBUG` (`CUCKOO_FIXTURE_FLAG` is never set) gets only `Item`'s constraint.
protocol TwoConditionFeed {
    #if DEBUG
    associatedtype Item
    func item() -> Item
    #endif
    #if CUCKOO_FIXTURE_FLAG
    associatedtype Tag
    func tag() -> Tag
    #endif
}

// The same associated type in both clauses exists in every build, with every clause's constraints.
protocol BothClausesFeed {
    #if DEBUG
    associatedtype Element
    #else
    associatedtype Element: Equatable
    #endif
    func element() -> Element
}
