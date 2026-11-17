// Requirements naming their own associated type through `Self`: `Self.Item`, its members, in an initializer, a
// variadic parameter and a constraint.
protocol Container {
    associatedtype Item: Sequence
    init(item: Self.Item)
    func first() -> Self.Item?
    func firstElement() -> Self.Item.Element?
    func kind() -> Self.Item.Type
    func add(_ item: Self.Item)
    func addAll(_ items: Self.Item...)
    func matching<T: Collection>(_ values: T) -> Bool where T.Element == Self.Item.Element
    var all: [Self.Item] { get }
}
