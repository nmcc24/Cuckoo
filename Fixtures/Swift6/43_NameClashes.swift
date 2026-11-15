// Members named like the mock's own stored properties and type-erasure storage: a property named `callMatcher`
// or `sourceLocation`, which the verification proxy keeps under its own names, and a backticked property in a
// protocol with an associated type, whose default-implementation storage is named after it.
protocol VerificationNames {
    var callMatcher: Int { get }
    var sourceLocation: String { get }
    func manager() -> Int
}

protocol KeywordProperty {
    associatedtype Element
    var `default`: Int { get }
    func take(_ element: Element)
}

// A superclass's typealias named like the mock's own types: the subclass's mock may redeclare it, since none of
// the subclass's members use it, so it's mocked. (A class that uses one is left out with a warning.)
class ClashingBase {
    typealias Verification = Int
    init() {}
}
class QuietSubclass: ClashingBase {
    override init() {}
    func count() -> Int { 0 }
}
