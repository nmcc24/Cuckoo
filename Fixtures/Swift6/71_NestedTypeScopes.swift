// Where a type is declared decides whether it's mocked and what its mock repeats.
protocol Service {
    func load() -> Int
}

// A final class isn't mocked, but the types nested in it are.
final class Outer {
    protocol Delegate {
        func done()
    }
    class Inner {
        init() {}
        func run() {}
    }
}

// A type local to a body, a closure or a `deinit` is invisible outside it, so it isn't mocked.
class Owner {
    init() {}
    deinit {
        final class Local: Service { func load() -> Int { 1 } }
        _ = Local()
    }
    func make() -> Int {
        class Local: Service { func load() -> Int { 1 } }
        return Local().load()
    }
}

// A backticked type name: its mock, stub and proxies are named without the backticks.
class `Type` {
    init() {}
    func a() {}
}

protocol `Protocol` {
    func a()
}

// A mock in an extension repeats its availability and its `where` clause.
struct Namespace {}

@available(macOS 14, iOS 17, tvOS 17, watchOS 10, *)
extension Namespace {
    protocol InExtension {
        func e()
    }
    class ClassInExtension {
        init() {}
        func c() {}
    }
}

enum Box<T> {}

extension Box where T == Int {
    class Counter {
        init() {}
        func count() -> T { 0 }
    }
}

// An `@available` message with commas in it, which isn't an `unavailable` argument.
protocol Deprecating {
    @available(*, deprecated, message: "old, unavailable soon, use new()")
    func old()
    func new()
}

#if canImport(ObjectiveC)
import Foundation

// An optional property requirement, which a default implementation may not implement.
@objc protocol Optionals {
    @objc optional var count: Int { get }
    @objc optional func refresh()
}
#endif
