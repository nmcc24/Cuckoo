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

// A class's member writing `Self` or an associated type as a concrete type implements the requirement; a requirement
// the class leaves to a default implementation is still mocked, through the class's typealias.
protocol Producing {
    associatedtype Output
    func make() -> Output
    func makeAll(_ count: Int) -> [Output]
    func combine(_ other: Self, with value: Output) -> Output?
}

extension Producing {
    func makeAll(_ count: Int) -> [Output] { [] }
}

class Maker: Producing {
    typealias Output = Int
    init() {}
    func make() -> Int { 0 }
    func make() -> String { "" }
    func combine(_ other: Maker, with value: Int) -> Int? { nil }
}

class SubMaker: Maker {}

protocol Same {
    func same(_ other: Self) -> Bool
}

class SameBase: Same {
    init() {}
    func same(_ other: SameBase) -> Bool { true }
}

// A placeholder stands for one whole type, the same one wherever the requirement writes it, and the type the class's
// typealias gives it: these members don't implement the requirements, which default implementations do.
protocol Pairing {
    associatedtype Output
    func f(_ a: (Output, Int))
    func h(_ c: (Output) -> Void)
    func k(_ a: Output, _ b: Output)
    func m(_ a: Output)
}

extension Pairing {
    func f(_ a: (Output, Int)) {}
    func h(_ c: (Output) -> Void) {}
    func k(_ a: Output, _ b: Output) {}
    func m(_ a: Output) {}
}

class Pairer: Pairing {
    typealias Output = Int
    init() {}
    func f(_ a: (Int, String, Int)) {}
    func h(_ c: (Int, Int) -> Void) {}
    func k(_ a: Int, _ b: String) {}
    func m(_ a: String) {}
}

// A `where` clause naming an associated type is matched as the member's types are.
protocol Picking {
    associatedtype Key
    func pick<T>(_ values: T) -> Key? where T: Sequence, T.Element == Key
}

class Picker: Picking {
    init() {}
    func pick<T>(_ values: T) -> String? where T: Sequence, T.Element == String { nil }
}

// A protocol's typealias is matched as what it stands for, a class's typealias of another as what that one stands
// for, and a member may write a placeholder both ways.
protocol Listing {
    associatedtype Item
    typealias Items = [Item]
    func all() -> Items
    func first(_ items: Self.Items) -> Item?
    func pair(_ first: Item, _ second: Item)
}

class Lister: Listing {
    typealias Number = Int
    typealias Item = Number
    init() {}
    func all() -> [Int] { [] }
    func first(_ items: [Item]) -> Int? { nil }
    func pair(_ first: Item, _ second: Int) {}
}

// A member type of a placeholder the class names, as `Output.Type`, is that type's.
protocol MetaTyping {
    associatedtype Output
    func accept(_ type: Output.Type)
}

extension MetaTyping {
    func accept(_ type: Output.Type) {}
}

class MetaTyper: MetaTyping {
    typealias Output = Int
    init() {}
    func accept(_ type: Int.Type) {}
    func accept(_ type: String) {}
}

// A requirement naming `Self` that the class leaves to the protocol's default implementation isn't mocked: the mock
// would have to write it with the class's type.
protocol Merging {
    func merged(with other: Self) -> Bool
    func copy() -> Self
    var me: Self { get }
    subscript(other: Self) -> Int { get }
    func kind(_ type: Self.Type) -> Int
}

extension Merging {
    func merged(with other: Self) -> Bool { false }
    func copy() -> Self { self }
    var me: Self { self }
    subscript(other: Self) -> Int { 0 }
    func kind(_ type: Self.Type) -> Int { 0 }
}

class Merger: Merging {
    init() {}
}

class OwnMerger: Merging {
    init() {}
    func merged(with other: OwnMerger) -> Bool { true }
}

class SubMerger: Merger {}

// A member type of an associated type the class names, as `Output.Element`, is one the class writes as it likes, and a
// placeholder on a constraint's left side is matched whatever order the constraints sort in.
protocol Indexing {
    associatedtype Output: Collection
    associatedtype Key
    associatedtype Value
    func first() -> Output.Element?
    func pair<T: Sequence, U: Sequence>(_ keys: T, _ values: U) where Value == T.Element, Key == U.Element
}

class IntIndex: Indexing {
    typealias Output = [Int]
    typealias Key = String
    typealias Value = Int
    init() {}
    func first() -> Int? { nil }
    func pair<T: Sequence, U: Sequence>(_ keys: T, _ values: U) where Int == T.Element, String == U.Element {}
}

// An associated type no typealias names stands for any type, so a same-named overload, written with `Int` where Swift
// infers `String`, is taken for the defaulted requirement, which the mock leaves to the protocol: it compiles.
protocol Keyed {
    associatedtype Key
    func get() -> Key
    func over<T: Sequence>(_ values: T) where T.Element == Key
    func pairs(_ first: Key, _ second: Key) -> Int
}

extension Keyed {
    func over<T: Sequence>(_ values: T) where T.Element == Key {}
    func pairs(_ first: Key, _ second: Key) -> Int { 0 }
}

class KeyStore: Keyed {
    init() {}
    func get() -> String { "" }
    func over<T: Sequence>(_ values: T) where T.Element == Int {}
    func pairs(_ first: String, _ second: Int) -> Int { 1 }
}

// With a default isolation, only the member Swift takes for the requirement's witness takes its actor.
@MainActor protocol Displaying {
    associatedtype Value
    func display(_ value: Value)
}

nonisolated class PlainDisplay: Displaying {
    typealias Value = Int
    init() {}
    func display(_ value: Int) {}
    func display(_ value: String) {}
}

// A conformance a plain extension states isn't the mock's: its members can't be overridden, a `where` clause limits
// it, and with a default isolation Swift doesn't give the class's own members its requirements' actor.
protocol Pinging {
    func ping() -> Int
}

extension Pinging {
    func ping() -> Int { 1 }
}

class PingBox<T> {
    init() {}
}

extension PingBox: Pinging where T: Equatable {}

protocol Signalling {
    func signal()
}

nonisolated class PlainSignaller {
    init() {}
    func signal() {}
}

extension PlainSignaller: Signalling {}

class SubSignaller: PlainSignaller {}

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

// A conformance an `@objc extension` declares itself: the class and its subclass's mocks override the members
// implementing it.
protocol Chiming {
    func chime() -> String
}

class ChimeBase: NSObject {}

@objc extension ChimeBase: Chiming {
    func chime() -> String { "" }
}

class Chimer: ChimeBase {}

// With a default isolation, a class's own member keeps its isolation for a protocol an `@objc extension` states.
protocol Tolling {
    func toll()
}

nonisolated class TollBase: NSObject {
    func toll() {}
}

@objc extension TollBase: Tolling {}

class Toller: TollBase {}

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
    _ = (MockChimer() as any Chiming).chime() + MockChimeBase().chime()
}
#endif
