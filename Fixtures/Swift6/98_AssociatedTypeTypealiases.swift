import Cuckoo

// A typealias of a type that names a non-primary associated type, `Items = [Item]`, in a generic member. The
// mock forwards such a member to a default implementation on the opened existential, where `Items` is another
// type: the type eraser casts the arguments and the result, as it does for the associated type itself. A typealias
// of a primary associated type is the same type there, and isn't cast.
protocol Listing {
    associatedtype Item
    typealias Items = [Item]
    typealias Pairs = [(Item, Int)]

    func first<T>(_ value: T) -> Items
    func item() -> Item
}

protocol PairListing: Listing {
    typealias Grid = [Items]

    func take<T>(_ items: Items, pairs: Pairs, also value: T) -> Pairs
    func each<T>(_ value: T, body: (Items) -> Void)
    func grid<T>(_ value: T) -> Grid
    subscript<T>(value: T) -> Items { get set }
}

protocol Keyed<Key> {
    associatedtype Key
    associatedtype Value
    typealias Keys = [Key]
    typealias Values = [Value]

    func keys<T>(_ value: T) -> Keys
    func values<T>(_ value: T, for keys: Keys) -> Values
}

struct Numbers: PairListing, Keyed {
    func first<T>(_ value: T) -> [Int] { [] }
    func item() -> Int { 0 }
    func take<T>(_ items: [Int], pairs: [(Int, Int)], also value: T) -> [(Int, Int)] { pairs }
    func each<T>(_ value: T, body: ([Int]) -> Void) { body([]) }
    func grid<T>(_ value: T) -> [[Int]] { [] }
    subscript<T>(value: T) -> [Int] {
        get { [] }
        set {}
    }
    func keys<T>(_ value: T) -> [String] { [] }
    func values<T>(_ value: T, for keys: [String]) -> [Int] { [] }
}

func useAssociatedTypeTypealiases() {
    let listing = MockPairListing<Int>()
    stub(listing) { stub in
        when(stub.first(any(String.self))).thenReturn([1])
    }
    listing.enableDefaultImplementation(Numbers())
    let items: [Int] = listing.first(1)
    let pairs: [(Int, Int)] = listing.take(items, pairs: [], also: "")
    listing.each(pairs.count) { _ in }
    listing[""] = listing.grid(1).first ?? []

    let keyed = MockKeyed<String, Int>()
    keyed.enableDefaultImplementation(Numbers())
    let values: [Int] = keyed.values(1, for: keyed.keys(1))
    _ = values
}
