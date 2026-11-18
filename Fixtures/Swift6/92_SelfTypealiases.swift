import Cuckoo

// Requirements naming a typealias through `Self`: the protocol's own, a parent's, one an extension declares, a
// generic one, and one of a function type, which makes a parameter a closure. Inside the mock, a class, `Self.ID`
// names no member type: it's written `ID`, which finds the mock's copy of the typealias.
protocol Identifying {
    typealias ID = Int
    typealias Callback = (Self.ID) -> Void
    typealias Pair<T> = (T, Self.ID)

    var current: Self.ID { get set }
    func find(_ id: Self.ID) -> Self.ID?
    func all() -> [Self.ID: [Self.ID]]
    func run(_ callback: Self.Callback)
    func keep(_ callback: @escaping Self.Callback)
    func pair(_ pair: Self.Pair<Self.ID>) -> Self.Pair<String>
    func matching<T: Sequence>(_ values: T) -> Bool where T.Element == Self.ID
    subscript(id: Self.ID) -> Self.ID { get }
}

extension Identifying {
    typealias Label = String
}

protocol Labelling: Identifying {
    func label(_ id: Self.ID) -> Self.Label
    // `Self`'s metatype stays `Self`'s.
    func kind() -> Self.Type
}

// Next to associated types, in the type eraser too.
protocol Listing {
    associatedtype Item
    typealias Items = [Item]
    typealias Key = String

    func items() -> Self.Items
    func key(_ key: Self.Key) -> Self.Key
    var keys: [Self.Key] { get set }
}

// A member's own generic parameter of the typealias's name: `Self.Key` is then the only way to name the typealias.
// The mock declares `__CuckooSelf_Key = Key`, which nothing shadows, and the member names that.
protocol Storing {
    typealias Key = String
    func get<Key>(_ key: Key) -> Self.Key
    func put<Key>(_ value: Key, as key: Self.Key, all keys: [Self.Key])
}

protocol Caching {
    associatedtype Item
    typealias Key = [Int]
    typealias Handler = (Item) -> Void
    func get<Key>(_ key: Key) -> Self.Key.Element
    func run<Handler>(_ value: Handler, with handler: Self.Key?) -> Self.Key
    func item() -> Item
}

// The same for a generic typealias, a function one, which makes the parameter a closure, one an extension
// declares and one of an associated type, in a generic mock and a nested one.
protocol PairStoring {
    associatedtype Item
    typealias Pair<T> = (T, Int)
    typealias Items = [Item]
    typealias Handler = (Int) -> Void

    func pair<Pair>(_ value: Pair) -> Self.Pair<Int>
    func items<Items>(_ value: Items, default items: Self.Items) -> Self.Items
    func handle<Handler>(_ value: Handler, with handler: Self.Handler)
    func tag<Tag>(_ value: Tag) -> Self.Tag
    func item() -> Item
}

extension PairStoring {
    typealias Tag = String
}

enum Stores {
    protocol Nested {
        typealias Key = String
        typealias Pair<T> = (T, Int)
        func get<Key>(_ key: Key) -> Self.Key
        func pair<Pair>(_ value: Pair) -> Self.Pair<Int>
    }
}

struct PairStorage: PairStoring, Stores.Nested {
    func pair<Pair>(_ value: Pair) -> (Int, Int) { (0, 0) }
    func items<Items>(_ value: Items, default items: [Int]) -> [Int] { items }
    func handle<Handler>(_ value: Handler, with handler: (Int) -> Void) { handler(0) }
    func tag<Tag>(_ value: Tag) -> String { "" }
    func item() -> Int { 0 }
    func get<Key>(_ key: Key) -> String { "" }
}

struct Storage: Storing, Caching {
    func get<Key>(_ key: Key) -> String { "" }
    func put<Key>(_ value: Key, as key: String, all keys: [String]) {}
    func get<Key>(_ key: Key) -> Int { 0 }
    func run<Handler>(_ value: Handler, with handler: [Int]?) -> [Int] { [] }
    func item() -> Int { 0 }
}

struct Identifier: Labelling {
    var current = 0
    func find(_ id: Int) -> Int? { id }
    func all() -> [Int: [Int]] { [:] }
    func run(_ callback: (Int) -> Void) { callback(current) }
    func keep(_ callback: @escaping (Int) -> Void) {}
    func pair(_ pair: (Int, Int)) -> (String, Int) { ("", pair.1) }
    func matching<T: Sequence>(_ values: T) -> Bool where T.Element == Int { true }
    subscript(id: Int) -> Int { id }
    func label(_ id: Int) -> String { "\(id)" }
    func kind() -> Identifier.Type { Identifier.self }
}

struct Names: Listing {
    var keys: [String] = []
    func items() -> [Int] { [] }
    func key(_ key: String) -> String { key }
}

func useSelfTypealiases() {
    let mock = MockLabelling()
    stub(mock) { stub in
        when(stub.find(1)).thenReturn(2)
        when(stub.label(any())).thenReturn("one")
        when(stub.run(any())).then { callback in callback(1) }
    }
    // A member naming only typealiases forwards to a default implementation: it doesn't name `Self`.
    mock.enableDefaultImplementation(Identifier())
    mock.run { _ in }
    verify(mock).pair(any())

    let listing = MockListing<Int>()
    listing.enableDefaultImplementation(Names())
    _ = listing.items()

    let storing = MockStoring()
    stub(storing) { stub in
        when(stub.get(any(Int.self))).thenReturn("one")
    }
    let key: String = storing.get(1)
    storing.enableDefaultImplementation(Storage())
    storing.put(1, as: key, all: [key])

    let caching = MockCaching<Int>()
    caching.enableDefaultImplementation(Storage())
    let element: Int = caching.get("")
    _ = caching.run(element, with: nil)

    let pairs = MockPairStoring<Int>()
    stub(pairs) { stub in
        when(stub.handle(any(String.self), with: any())).then { _, handler in handler(1) }
    }
    pairs.handle("") { _ in }
    let forwarding = MockPairStoring<Int>()
    forwarding.enableDefaultImplementation(PairStorage())
    let pair: (Int, Int) = forwarding.pair("")
    let items: [Int] = forwarding.items("", default: [pair.0])
    let tag: String = forwarding.tag(items)

    let nested = Stores.MockNested()
    nested.enableDefaultImplementation(PairStorage())
    let nestedPair: (Int, Int) = nested.pair(tag)
    _ = nested.get(nestedPair.0)
}
