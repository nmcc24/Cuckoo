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
