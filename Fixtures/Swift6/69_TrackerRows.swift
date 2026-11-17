// Shapes from the findings tracker, checked against the generator: an actor protocol with an associated type, a
// static `Void` requirement and a generic subscript next to an associated type, a module-qualified parent and an
// `@unchecked Sendable` extension written qualified, and names that look like Cuckoo's through two parents.
protocol ActorStore: Actor {
    associatedtype Item
    func load() -> Item
}

protocol Resettable {
    associatedtype Item
    static func reset()
    static func make() -> Int
    subscript<Key: Hashable>(key: Key) -> Item? { get }
}

enum Fix {
    class Base {
        init() {}
        func run() {}
    }

    class Holder {
        init() {}
        func hold() {}
    }
}

class Derived: Fix.Base {
    override init() {}
    func extra() {}
}

extension Fix.Holder: @unchecked Sendable {}

protocol R {
    func stubbing() -> Int
}

protocol Q: R {}

protocol PP: Q {
    func verification() -> Int
}

typealias Stubbing = Int

protocol UsesStubbing {
    func value() -> Stubbing
}
