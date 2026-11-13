/// Associated types constrained in their own `where` clauses, including a requirement on a nested type.
protocol ConstrainedAssociatedTypes {
    associatedtype Element where Element: Equatable
    associatedtype Items: Collection where Items.Element == Int

    func echo(_ element: Element) -> Element
    func first(of items: Items) -> Int?
}
