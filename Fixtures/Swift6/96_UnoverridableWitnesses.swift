// A class implementing a protocol's requirements with members its mock can't override: `static` or `final` ones.
// The mock leaves them alone, as it does the class's other `static` and `final` members, and doesn't declare the
// protocol's requirement next to them.
protocol Counting {
    static var shared: Int { get }
    static func reset()
    var count: Int { get }
    func increment()
    func decrement()
    subscript(index: Int) -> Int { get }
}

class Counter: Counting {
    init() {}
    static var shared: Int { 0 }
    static func reset() {}
    final var count: Int { 0 }
    final func increment() {}
    func decrement() {}
    final subscript(index: Int) -> Int { index }
}
