// The type eraser's remaining paths: settable plain and generic subscripts, static members (which the eraser
// leaves to the mock), a typed-throws getter, a settable property and a variadic method.
enum ProbeError: Error {
    case failed
}

protocol ProbeStore {
    associatedtype Item
    subscript(index: Int) -> Item { get set }
    subscript<Key: Hashable>(key key: Key) -> Item? { get set }
    static var shared: Int { get set }
    static subscript(name: String) -> Int { get set }
    var checked: Item { get throws(ProbeError) }
    var count: Int { get set }
    func put(_ items: Item...)
}
