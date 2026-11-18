import Cuckoo

// A class implementing a protocol's requirements with members its mock can't override: `static` or `final` ones.
// The mock leaves them alone, as it does the class's other `static` and `final` members, and doesn't declare the
// protocol's requirement next to them. The same goes for members an extension of the class declares, whatever
// they are, and for such members of a superclass, whose subclass states the protocol.
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

// The requirements a superclass implements that way, in its body or in an extension, for a subclass that states
// the protocol. A generic superclass is found without its arguments.
protocol Resetting {
    static func reset()
    func ping()
    func hello()
    func open()
}

class ResetBase {
    init() {}
    static func reset() {}
    final func ping() {}
    func open() {}
}

extension ResetBase {
    func hello() {}
}

class ResetChild: ResetBase, Resetting {}

class ResetGrandchild: ResetChild {}

class GenericResetBase<Value> {
    init() {}
    static func reset() {}
    final func ping() {}
    final func open() {}
}

extension GenericResetBase {
    func hello() {}
}

class GenericResetChild: GenericResetBase<Int>, Resetting {}

func useSuperclassWitnesses() {
    let mock = MockResetChild()
    stub(mock) { stub in
        when(stub.open()).thenDoNothing()
    }
    mock.open()
    mock.ping()
    mock.hello()
    MockResetChild.reset()
    MockResetGrandchild().hello()
    MockGenericResetChild().ping()
    verify(mock).open()
}

#if canImport(ObjectiveC)
import Foundation

// An `override` in an extension, which only an `@objc dynamic` member allows, hides nothing: the mock overrides the
// superclass's member again.
class DynamicBase: NSObject {
    @objc dynamic func refresh() {}
}

class DynamicChild: DynamicBase {}

extension DynamicChild {
    override func refresh() {}
}

func useDynamicOverride() {
    let mock = MockDynamicChild()
    stub(mock) { stub in
        when(stub.refresh()).thenDoNothing()
    }
    mock.refresh()
    verify(mock).refresh()
}

// A plain `@objc` member an extension declares is dispatched through the Objective-C runtime too, so it hides
// nothing either: it implements the requirement it matches, and the mock overrides it, calling it through `super`.
class GreeterBase: NSObject {}

extension GreeterBase {
    @objc func hello() {}
    @objc var name: String { "" }
}

protocol Greeting {
    func hello()
    var name: String { get }
}

class Greeter: GreeterBase, Greeting {}

// `dynamic` alone allows dynamic replacement, not an override, so it still hides the requirement it implements.
class ReplaceableBase: NSObject {}

extension ReplaceableBase {
    dynamic func hello() {}
}

protocol Replaceable {
    func hello()
}

class Replaced: ReplaceableBase, Replaceable {}

// The isolation an extension states stays with its `@objc` member in the mock.
@MainActor
class IsolatedGreeterBase: NSObject {}

nonisolated extension IsolatedGreeterBase {
    @objc func wave() {}
}

protocol Waving {
    nonisolated func wave()
}

class IsolatedGreeter: IsolatedGreeterBase, Waving {}

func useObjcExtensionWitness() {
    let mock = MockGreeter()
    stub(mock) { stub in
        when(stub.hello()).thenDoNothing()
        when(stub.name.get).thenReturn("stubbed")
    }
    mock.hello()
    _ = (mock as any Greeting).name
    verify(mock).hello()
}
#endif
