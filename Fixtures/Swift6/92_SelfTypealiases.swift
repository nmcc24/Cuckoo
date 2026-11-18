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

// A member's own generic parameter of the typealias's name: `Self.Key` is then the only way to name the typealias,
// and the mock names it through its own type, `MockStoring.Key`. A generic mock's type would bring its associated
// types into the member's types, so there the typealias is written out.
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
}
