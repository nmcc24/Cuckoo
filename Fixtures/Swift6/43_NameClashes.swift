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


// Names the mock's own used to hide before they carried Cuckoo's prefix: associated types, generic parameters,
// nested types and typealiases named Stubbing, Verification or MocksType, declared, inherited or used unqualified,
// and a type named like the old matcher generics, M1.
protocol StubbingSource {
    associatedtype Stubbing
    func next() -> Stubbing
}
protocol RefinedStubbingSource: StubbingSource {
    func refresh()
}
class VerificationBase {
    struct Verification {}
    init() {}
    func check(_ verification: Verification) -> Bool { true }
}
class VerificationChild: VerificationBase {
    func record(_ verification: Verification) {}
}
typealias MocksType = Int
protocol UsesTopLevelMocksType {
    func count() -> MocksType
}
struct M1 {}
protocol TakesM1 {
    func take(_ value: M1, count: Int)
}
protocol ReferenceHolder {
    associatedtype Item
    var reference: Item { get }
}
