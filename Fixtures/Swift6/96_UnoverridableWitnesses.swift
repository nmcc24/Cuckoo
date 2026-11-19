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

// A member with fewer effects than the requirement it implements, as Swift allows: a `func load()` that doesn't
// throw implements `func load() throws`, and a synchronous one an `async` requirement. The mock overrides the
// class's member, not the requirement.
protocol Loading {
    func load() throws -> Int
    func later() async -> Int
    subscript(index: Int) -> Int { get throws }
}

class Loader: Loading {
    init() {}
    func load() -> Int { 0 }
    func later() -> Int { 0 }
    subscript(index: Int) -> Int { index }
}

// A superclass's sync and `async` overloads are two members: the sync one doesn't implement the other, so the
// mock overrides both.
class Overloaded {
    init() {}
    func value() -> Int { 0 }
    func value() async -> Int { 1 }
}

class OverloadedChild: Overloaded {}

// With a default isolation, a member with fewer effects takes the actor of the requirement it implements, as one
// with the same effects does.
@MainActor
protocol Showing {
    func show() async throws
}

nonisolated class PlainShower {
    init() {}
}

class Shower: PlainShower, Showing {
    func show() {}
}

// A typed throw is fewer effects than an untyped one, `throws(any Error)` included.
enum ParseError: Error {
    case bad
}

protocol Parsing {
    func parse() throws -> Int
    func check() throws(any Error)
}

class TypedParser: Parsing {
    init() {}
    func parse() throws(ParseError) -> Int { 0 }
    func check() throws(ParseError) {}
}

// `throws` and `throws(any Error)` are one effect, however each side spells it.
protocol AnyErrorChecking {
    func verify() throws(any Error)
}

class AnyErrorChecker: AnyErrorChecking {
    init() {}
    func verify() throws {}
}

func useFewerEffects() throws {
    let mock = MockLoader()
    stub(mock) { stub in
        when(stub.load()).thenReturn(1)
    }
    _ = mock.load() + mock.later() + mock[0]
    verify(mock).load()
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

// The same for a plain `@objc` member an extension declares.
class LoaderBase: NSObject {}

extension LoaderBase {
    @objc func fetch() {}
    @objc func refresh() {}
}

protocol Fetching {
    func fetch() throws
    func refresh() async
}

class Fetcher: LoaderBase, Fetching {}

// Every member of an `@objc extension` is `@objc`, so the mock overrides the requirement it implements, unless it's
// `@nonobjc`, which the mock leaves alone, as any extension member.
class ObjcExtensionBase: NSObject {}

@objc extension ObjcExtensionBase {
    func ring() {}
    var tone: String { "" }
    @nonobjc func mute() {}
}

protocol Ringing {
    func ring()
    var tone: String { get }
    func mute()
}

class Ringer: ObjcExtensionBase, Ringing {}

// An `@objcMembers` class's extension members are `@objc` only when Objective-C can represent their types, which
// the generator can't tell from the sources: one implementing a requirement stays the class's, unmocked, unless it
// says `@objc` itself.
@objcMembers
class MembersBase: NSObject {}

extension MembersBase {
    func greet() {}
    @objc func wave() {}
}

protocol Greeting2 {
    func greet()
    func wave()
}

class MembersGreeter: MembersBase, Greeting2 {}

func useObjcExtensionWitness() {
    let mock = MockGreeter()
    stub(mock) { stub in
        when(stub.hello()).thenDoNothing()
        when(stub.name.get).thenReturn("stubbed")
    }
    mock.hello()
    _ = (mock as any Greeting).name
    verify(mock).hello()

    let fetcher = MockFetcher()
    stub(fetcher) { stub in
        when(stub.fetch()).thenDoNothing()
    }
    fetcher.fetch()
    fetcher.refresh()
    MockRinger().ring()
    _ = MockRinger().tone
    MockRinger().mute()
    MockMembersGreeter().greet()
    MockMembersGreeter().wave()
}
#endif
