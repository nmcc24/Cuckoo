import Cuckoo

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
