// `where` clauses on associated types and on the protocol: requirements on an associated type constrain the mock's
// generic parameter, a same-type requirement becomes a typealias, and one on a nested type, such as
// `Items.Element == Int`, goes in the mock's and stub's own `where` clause.
protocol ConstrainedElement {
    associatedtype Element where Element: Equatable
    func get() -> Element
}

protocol ConstrainedItems {
    associatedtype Items: Collection where Items.Element == Int
    func items() -> Items
}

protocol SameTypeAssociatedTypes {
    associatedtype A
    associatedtype B where B == A
    func convert(_ a: A) -> B
}

protocol ProtocolWhereOnNestedType where Items.Element: Hashable {
    associatedtype Items: Collection
    func items() -> Items
}

protocol RefinesConstrainedItems: ConstrainedItems {
    func count() -> Int
}
