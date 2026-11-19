import Cuckoo
import Foundation

// Shapes from the final review of the generator, one section per finding.

// A module type as a `Set` element or a dictionary key. With a default isolation its `Hashable` conformance is
// isolated to the default actor, so the stubbing proxy stubs on that actor.
struct ReviewItem: Hashable {
    var id = 0
}

protocol ReviewCatalog {
    func all() -> Set<ReviewItem>
    func counts(_ items: [ReviewItem: Int]) -> Int
    var tags: Set<ReviewItem> { get }
}

class ReviewStore {
    init() {}
    func items() -> Set<ReviewItem> { [] }
}

func useReviewCatalog() {
    let mock = MockReviewCatalog()
    stub(mock) { stub in
        when(stub.all()).thenReturn([ReviewItem()])
        when(stub.tags.get).thenReturn([])
    }
    _ = mock.all()
    verify(mock).all()
}

// A `rethrows` requirement of a protocol with associated types, and a generic one whose closure takes an `inout`
// associated type: the type eraser can't forward either to a default implementation, so they record a failure
// saying to stub them instead. They're still mocked.
protocol ReviewVisiting {
    associatedtype Element
    func each(_ body: (Element) throws -> Void) rethrows
    func update<R>(_ body: (inout Element) throws -> R) rethrows -> R
}

func useReviewVisiting() {
    let mock = MockReviewVisiting<Int>()
    stub(mock) { stub in
        when(stub.each(any())).thenDoNothing()
    }
    mock.each { _ in }
    verify(mock).each(any())
}

// A generic class naming itself without its arguments, as Swift allows inside it: the mock is another class, so it
// writes `ReviewBox<T, U>`, nested types and a nested class included.
class ReviewBox<T: Hashable, U> {
    struct Entry {
        var key: T
    }

    init() {}
    func merged(with other: ReviewBox) -> ReviewBox { self }
    func entries() -> [ReviewBox.Entry] { [] }
    func mapped<V: Hashable>(_ transform: (T) -> V) -> ReviewBox<V, U>? { nil }

    class Child {
        init() {}
        func parent() -> ReviewBox? { nil }
    }
}

// A property's type is read from its initializer only when the text settles it: a literal, a cast, or a call of a
// standard-library type. Anything else, as a call of a type of the sources, which may be failable or an enum case,
// or a generic type without arguments, is left unmocked with a warning.
enum ReviewKind: Int {
    case one = 1
}

enum ReviewShape {
    case Circle(Int)
}

struct ReviewWrapper {
    init?(text: String) {}
}

class ReviewGuesses {
    init() {}
    var kind = ReviewKind(rawValue: 1)
    var wrapper = ReviewWrapper(text: "x")
    var task = Task { 1 }
    var shape = ReviewShape.Circle(3)
    var numbers: Array = [1, 2]
    var count = 0
}

// Two parents requiring one property or subscript with different accessors: the mock's is settable and has the
// fewer effects, so it conforms to both: an untyped `throws` and a typed one give the typed one.
protocol ReviewReading {
    var value: Int { get }
    var status: String { get async }
    var cached: Int { get throws }
    subscript(index: Int) -> Int { get }
    subscript(key: String) -> Int { get throws }
}

protocol ReviewWriting {
    var value: Int { get set }
    var status: String { get }
    var cached: Int { get throws(ReviewLoadError) }
    subscript(index: Int) -> Int { get set }
    subscript(key: String) -> Int { get throws(ReviewLoadError) }
}


protocol ReviewReadWriting: ReviewReading, ReviewWriting {}

func useReviewReadWriting() {
    let mock = MockReviewReadWriting()
    stub(mock) { stub in
        when(stub.value.set(any())).thenDoNothing()
    }
    mock.value = 1
    verify(mock).value.set(1)
}

// A class conforming to an error protocol is nonisolated with a default isolation, as Swift makes it.
class ReviewFailure: Error, @unchecked Sendable {
    init() {}
    func describe() -> String { "" }
}

class ReviewLocalizedFailure: LocalizedError, @unchecked Sendable {
    init() {}
    func describe() -> String { "" }
}

// A public subclass of a class whose mock is internal, because a member names an internal type, gets an internal
// mock too: it inherits that member.
struct ReviewInternalThing {}

open class ReviewOpenBase {
    public init() {}
    func use(_ thing: ReviewInternalThing) {}
}

public class ReviewPublicSub: ReviewOpenBase {
    public override init() {
        super.init()
    }
}

// A `nonisolated(unsafe)` stored property is the class's own storage: the mock leaves it alone.
@MainActor
class ReviewCounter {
    init() {}
    nonisolated(unsafe) var hits = 0
    func count() -> Int { 0 }
}

// A class's explicit `nonisolated init`: with a default isolation, the mock and stub override it as nonisolated,
// since the one they'd inherit takes the default actor, and its other designated initializers too, which an override
// would otherwise stop them inheriting. A convenience initializer is inherited.
class ReviewPlainMaker {
    nonisolated init() {}
    nonisolated init(seed: Int) throws {}
    init(name: String) {}
    nonisolated convenience init(other: Int) { self.init() }
    func make() -> Int { 0 }
}

// A subclass declaring a designated initializer has only its own, so only those are overridden.
class ReviewBaseMaker {
    nonisolated init() {}
    init(name: String) {}
}

class ReviewSubMaker: ReviewBaseMaker {
    nonisolated override init() { super.init() }
    init(count: Int) { super.init(name: "") }
}

class ReviewAsyncMaker {
    nonisolated init() async {}
    func make() -> Int { 0 }
}

// A child restating a parent's requirement with the type the parent fixes its associated type to is one
// requirement, not two.
protocol ReviewRepository {
    associatedtype Item
    func all() -> [Item]
}

protocol ReviewUserRepository: ReviewRepository where Item == String {}

protocol ReviewNamedUserRepository: ReviewUserRepository {
    func all() -> [String]
}

#if canImport(ObjectiveC)
// A C function pointer is a value, not a closure the call owns: the mock records it as it is.
@objc protocol ReviewCallbacks {
    func register(_ callback: @convention(c) (Int32) -> Int32)
}
#endif
