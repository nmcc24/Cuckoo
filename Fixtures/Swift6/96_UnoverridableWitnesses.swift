import Cuckoo

// A class implementing a protocol's requirements with members its mock can't override: `static` or `final` ones.
// The mock leaves them alone, as it does the class's other `static` and `final` members, and doesn't declare the
// protocol's requirement next to them. The same goes for members an extension of the class declares, whatever
// they are.
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

protocol Refreshing {
    static func make() -> Self
    var stamp: Int { get }
    func refresh()
    func reload()
    subscript(key: String) -> Int { get }
}

class Feed: Refreshing {
    required init() {}
    func reload() {}
}

extension Feed {
    static func make() -> Self { self.init() }
    var stamp: Int { 0 }
    func refresh() {}
    subscript(key: String) -> Int { 0 }
}

// A subclass inherits them, and an extension of a nested class is found by its qualified name.
class LiveFeed: Feed {}

enum Feeds {
    class Cached: Refreshing {
        required init() {}
        func reload() {}
    }
}

extension Feeds.Cached {
    static func make() -> Self { self.init() }
    var stamp: Int { 0 }
    func refresh() {}
    subscript(key: String) -> Int { 0 }
}

func useExtensionWitnesses() {
    let mock = MockFeed()
    stub(mock) { stub in
        when(stub.reload()).thenDoNothing()
    }
    mock.reload()
    mock.refresh()
    _ = mock.stamp + mock["a"] + MockLiveFeed().stamp + Feeds.MockCached().stamp
    verify(mock).reload()
}
