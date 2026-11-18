// Members the builders write as Swift needs them.
final class Box {}

// A settable closure property or subscript in a protocol with an associated type: the type eraser stores its
// setter as a closure taking an escaping value.
protocol Observing {
    associatedtype Value
    var onChange: (Value) -> Void { get set }
    var handler: @Sendable (Int) -> Void { get set }
    subscript(key key: Int) -> (Value) -> Void { get set }
}

// A generic requirement taking a non-escaping closure over an associated type: the type eraser adapts it.
protocol Mapping {
    associatedtype Element
    func map<T>(_ transform: (Element) -> T) -> [T]
    func each(_ body: (Element) -> Void)
}

// A subscript whose key is labelled `p0`, the name the mock gives the first parameter.
protocol Labelled {
    subscript(p0 index: Int) -> Int { get }
}

// A closure key next to a generic subscript that would also take it.
protocol Keyed {
    subscript(_ transform: (Int) -> Int) -> Int { get }
    subscript<T>(t: T) -> Int where T: Sendable { get }
}

// A sync and an async overload of the same signature: `await verify(mock).value()` verifies the async one.
class Overloads {
    init() {}
    func value() -> Int { 0 }
    func value() async -> Int { 0 }
}

// An `isolated` parameter with a non-escaping closure: the protocol's mock can't forward it to a default
// implementation, and a class's mock keeps the real implementation (warned).
protocol Running {
    func run<T>(isolation: isolated (any Actor)?, _ body: () async throws -> T) async rethrows -> T
    func run(_ actor: isolated (any Actor)?, body: () -> Void) async
}

// Types nested two levels deep name their outer scopes' types as the source does.
enum Feature {
    struct Model {}
    enum Screen {
        class ViewModel {
            init() {}
            func load(_ model: Model) -> Screen? { nil }
        }
        protocol Routing {
            typealias Models = [Model]
            func route(to model: Model, all: Models)
        }
    }
}

// A sync member with an `isolated` parameter and a non-escaping closure forwards as any member does.
actor Worker {}

protocol SyncRunning {
    func run(_ worker: isolated Worker, body: () -> Void)
}

class SyncRunner {
    init() {}
    func run(_ worker: isolated Worker, body: () -> Int) -> Int { body() }
}

// An outer type hidden by one a superclass declares, or by a type declared under `#if`, gets no typealias.
enum Area {
    struct Thing {}
    struct Model {}
    #if DEBUG
    struct Debugged {}
    #endif
    enum Screen {
        class Base {
            init() {}
            struct Thing {}
        }
        class ViewModel: Base {
            func load(_ thing: Thing, _ model: Model) {}
            #if DEBUG
            func debug(_ value: Debugged) {}
            #endif
        }
    }
}
