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
}
