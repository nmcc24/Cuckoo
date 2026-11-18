// Members a class or protocol takes from its parents.

// A subclass's `final` or unavailable override hides the superclass's member, which the mock can't override.
class Base {
    init() {}
    func foo() {}
    func bar() {}
    var prop: Int { 1 }
    subscript(i: Int) -> Int { i }
}

class Child: Base {
    final override func foo() {}
    final override var prop: Int { 2 }
    @available(*, unavailable) override func bar() {}
    final override subscript(i: Int) -> Int { i }
    func own() {}
}

// A parent with no global actor keeps its requirements nonisolated in a protocol that has one.
protocol Loggable {
    func log()
}

@MainActor
protocol Presenter {
    func present()
}

@MainActor
protocol HomePresenter: Loggable {
    func home()
}

protocol DetailPresenter: Presenter, Loggable {
    func detail()
}

// A parent's associated type fixed by the child no longer names a generic parameter in the other ones'
// constraints.
protocol Listing {
    associatedtype Item
    associatedtype Items: Sequence where Items.Element == Item
    func items() -> Items
}

protocol Names: Listing where Item == String {
    func first() -> Item
}

protocol Store<Key, Value> {
    associatedtype Key: Hashable
    associatedtype Value
    associatedtype Keys: Collection<Key>
    func get(_ key: Key) -> Value?
    func all() -> Keys
}

protocol IntStore: Store where Key == Int {
    func sum() -> Int
}

protocol StringStore: Store<String, Int> {}

// A requirement restated by a child with other spellings is the same requirement.
protocol Restated {
    func f<T>(_ t: T)
    func h<T: Equatable>(a: T) -> T
    func m(x: Swift.Int)
}

protocol Restating: Restated {
    func f<U>(_ u: U)
    func h<V>(a: V) -> V where V: Equatable
    func m(x: Int)
}

// Requirements naming `Self`'s metatype.
protocol Metatyped {
    func meta() -> Self.Type
    func take(_ type: Self.Type)
    var kind: Self.Type { get }
}

// A subscript with a `_modify` accessor is settable.
class Modifying {
    init() {}
    var storage = [0]
    subscript(i: Int) -> Int {
        get { storage[i] }
        _modify { yield &storage[i] }
    }
}

// Closure typealiases through other typealiases, and a generic one applied to itself.
typealias Handler = (Int) -> Void
typealias Chained = Handler
typealias Transform<T> = (T) -> T

protocol Handling {
    func handle(_ handler: Chained)
    func transform(_ transform: Transform<Transform<Int>>)
}

class HandlingClass {
    init() {}
    func handle(_ handler: Chained) {}
}

// Isolation inherited from a superclass, a parent protocol or the type a class is nested in, which the module's
// default isolation doesn't replace.
nonisolated class Plain {
    init() {}
    func c() {}
}

class PlainChild: Plain {
    func d() {}
}

nonisolated protocol Unisolated {
    func n()
}

protocol UnisolatedChild: Unisolated {
    func c()
}

nonisolated struct Holder {
    class Nested {
        init() {}
        func x() {}
    }
}
