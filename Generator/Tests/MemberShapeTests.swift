import Testing
@testable import CuckooGenerator

/// How the mocks spell members whose isolation, type or overloads the generator has to work out. The fixture matrix
/// and the runtime tests compile the results; these pin the generated text, on Linux too for the Objective-C ones.
@Suite
struct MemberShapeTests {
    private static let mainActor = #"defaultIsolation = "MainActor""#

    /// Swift gives a type declared in an extension the module's default isolation, even when the extended type is
    /// `nonisolated`; only a type declared in that type's body is nonisolated with it.
    @Test
    func aTypeInAnExtensionOfANonisolatedTypeTakesTheDefaultIsolation() async throws {
        let source = """
            nonisolated struct Holder {
                class InBody {
                    init() {}
                    func x() {}
                }
            }
            extension Holder {
                class InExtension {
                    init() {}
                    func x() {}
                }
            }
            """
        let output = try await generateMocks(source: source, options: Self.mainActor)
        #expect(output.contains("nonisolated final class MockInBody: InBody,"))
        #expect(output.contains("    final class MockInExtension: InExtension,"))
        #expect(!output.contains("nonisolated final class MockInExtension"))
    }

    /// With a default isolation, a `nonisolated` class's member takes the global actor of the requirement it
    /// implements, as Swift infers it.
    @Test
    func aWitnessInANonisolatedClassTakesItsRequirementsActor() async throws {
        let source = """
            @globalActor actor Background { static let shared = Background() }
            nonisolated class Plain {
                init() {}
            }
            protocol Showing {
                func show()
                nonisolated func describe()
            }
            @Background protocol Syncing {
                var synced: Bool { get }
            }
            class Screen: Plain, Showing, Syncing {
                func show() {}
                func describe() {}
                var synced: Bool { true }
                func own() {}
            }
            """
        let isolated = try await generateMocks(source: source, options: Self.mainActor)
        let mock = try #require(isolated.firstRange(of: "class MockScreen").map { String(isolated[$0.lowerBound...]) })
        #expect(mock.contains("@MainActor\n    override func show()"))
        #expect(mock.contains("@Background\n    override var synced: Bool"))
        #expect(mock.contains("\n    override func describe()"))
        #expect(mock.contains("\n    override func own()"))
        #expect(!mock.contains("@MainActor\n    override func describe()"))
        #expect(!mock.contains("@MainActor\n    override func own()"))

        // Without a default isolation Swift infers nothing for a `nonisolated` class's members.
        let plain = try await generateMocks(source: source)
        #expect(!plain.contains("@MainActor\n    override func show()"))
        #expect(!plain.contains("@Background\n    override var synced"))
    }

    /// An `@objc optional` property or subscript reads as an optional through its protocol and can't be assigned:
    /// the getter unwraps the default implementation's value, and the setter records a failure.
    @Test
    func anObjcOptionalSetterIsNotForwarded() async throws {
        let source = """
            import Foundation
            @objc protocol Configurable {
                @objc optional var count: Int { get set }
                @objc optional subscript(index: Int) -> String { get set }
                var required: Int { get set }
            }
            """
        let output = try await generateMocks(source: source)
        let unforwardable = #"reason: "Swift can't assign to an '@objc optional' requirement through its protocol")"#
        #expect(output.contains("defaultCall: cuckooDefaultImplementation.value.count!"))
        #expect(output.contains(#"defaultCall: cuckooManager.unforwardableDefaultImplementationCall("count", \#(unforwardable)"#))
        #expect(!output.contains("cuckooDefaultImplementation.value.count = newValue"))
        #expect(output.contains("defaultCall: cuckooDefaultImplementation.value[p0]!"))
        #expect(output.contains(#"defaultCall: cuckooManager.unforwardableDefaultImplementationCall("subscript(_ p0: Int) -> String#set", \#(unforwardable)"#))
        #expect(!output.contains("cuckooDefaultImplementation.value[p0] = "))
        #expect(output.contains("defaultCall: cuckooDefaultImplementation.value.required = newValue"))
    }

    /// `Self.ID` is written `ID` in the mock, whatever `ID` is, and a function typealias named through `Self` is
    /// the closure it stands for.
    @Test
    func aTypealiasNamedThroughSelfIsUnqualified() async throws {
        let source = """
            protocol Identifying {
                typealias ID = Int
                typealias Callback = (Self.ID) -> Void
                func find(_ id: Self.ID) -> [Self.ID]
                func run(_ callback: Self.Callback)
                func shadowing<ID>(_ id: ID) -> Self.Type
            }
            """
        let output = try await generateMocks(source: source)
        #expect(output.contains("typealias Callback = (ID) -> Void"))
        #expect(output.contains("func find(_ p0: ID) -> [ID] {"))
        #expect(output.contains("func run(_ p0: (ID) -> Void) {"))
        #expect(!output.contains("Self.ID"))
        #expect(!output.contains("Self.Callback"))
        // `Self.Type` is still the mock's own metatype.
        #expect(output.contains("func shadowing<ID> (_ p0: ID) -> __CuckooSelf.Type {"))
    }

    /// The type eraser's stored setters take the new value `inout`, and name an implicitly unwrapped optional as the
    /// optional it is.
    @Test
    func theTypeEraserStoresSettersOfAnyValue() async throws {
        let source = """
            typealias Handler = (Int) -> Void
            protocol Observed {
                associatedtype Value
                var handler: Handler { get set }
                var implicit: Value! { get set }
            }
            """
        let output = try await generateMocks(source: source)
        #expect(output.contains("private let _setter_storage$$handler: @Sendable (inout Handler) -> Void"))
        #expect(output.contains("private let _getter_storage$$implicit: @Sendable () -> Value?"))
        #expect(output.contains("private let _setter_storage$$implicit: @Sendable (inout Value?) -> Void"))
        #expect(output.contains("var implicit: Value! {"))
    }

    /// The async overload of a sync and async pair is a member of each proxy's `async`, not `async` itself, and
    /// the proxy's own member is the sync one. Only such overloads are there.
    @Test
    func anAsyncOverloadOfASyncMethodIsNamedThroughAsync() async throws {
        let source = """
            protocol Loading {
                func value() -> Int
                func value() async -> Int
                func load(_ id: Int) async -> Int
                func load(_ id: String) -> Int
                func refresh() async
                static func shared() -> Int
            }
            protocol Plain {
                func refresh() async
            }
            """
        let output = try await generateMocks(source: source)
        let plainStart = try #require(output.firstRange(of: "class MockPlain"))
        let loading = String(output[..<plainStart.lowerBound])
        // The stubbing and the verification proxy of the instance members, not the static ones'.
        #expect(loading.split(separator: "var async: __Async {").count == 3)
        #expect(loading.split(separator: "nonisolated struct __Async {").count == 3)
        #expect(loading.contains("return .init(cuckooManager: cuckooManager, cuckooCallMatcher: cuckooCallMatcher, cuckooSourceLocation: cuckooSourceLocation)"))
        #expect(loading.contains("\n        func value() -> Cuckoo.ProtocolStubFunction<(), Int, (()) -> Int,"))
        #expect(loading.contains("\n            func value() -> Cuckoo.ProtocolStubFunction<(), Int, nonisolated(nonsending) (()) async -> Int,"))
        #expect(loading.split(separator: "func value() -> Cuckoo.VerifiedCall<(), Int>").count == 3)
        // No proxy member is `async`: different parameters tell `load` apart already.
        #expect(!loading.contains("async -> Cuckoo."))
        // Mock, stubbing, verification and stub class: `refresh()` has no sync overload, and no member in `async`.
        #expect(loading.split(separator: "func refresh()").count == 5)
        #expect(!output[plainStart.lowerBound...].contains("__Async"))
    }

    /// A mocked member named `async` takes the name. The async overload's proxy members are then `async`
    /// themselves, on their caller's actor, which keeps a proxy that isn't `Sendable` there.
    @Test
    func anAsyncOverloadNextToAMemberNamedAsyncIsNamedWithAwait() async throws {
        let source = """
            protocol Named {
                var async: Bool { get }
                func value() -> Int
                func value() async -> Int
            }
            """
        let output = try await generateMocks(source: source)
        #expect(!output.contains("__Async"))
        #expect(output.contains("func value() -> Cuckoo.ProtocolStubFunction<(), Int, (()) -> Int,"))
        #expect(output.contains("nonisolated(nonsending) func value() async -> Cuckoo.ProtocolStubFunction<(), Int, nonisolated(nonsending) (()) async -> Int,"))
        #expect(output.contains("nonisolated(nonsending) func value() async -> Cuckoo.VerifiedCall<(), Int>"))
    }

    /// A class's `static` or `final` member that implements a protocol's requirement hides the requirement, which
    /// the mock would otherwise declare next to it.
    @Test
    func aRequirementImplementedByAnUnoverridableMemberIsNotMocked() async throws {
        let source = """
            protocol Counting {
                static func reset()
                var count: Int { get }
                func increment()
                func decrement()
            }
            class Counter: Counting {
                init() {}
                static func reset() {}
                final var count: Int { 0 }
                final func increment() {}
                func decrement() {}
            }
            """
        let output = try await generateMocks(source: source)
        let mock = try #require(output.firstRange(of: "class MockCounter").map { String(output[$0.lowerBound...]) })
        #expect(mock.contains("override func decrement()"))
        #expect(!mock.contains("func reset()"))
        #expect(!mock.contains("func increment()"))
        #expect(!mock.contains("var count: Int"))
    }

    /// A member an extension of the class declares can't be overridden, so it hides the requirement it implements
    /// as a `final` one does; an extension of another type doesn't.
    @Test
    func aRequirementImplementedInAnExtensionIsNotMocked() async throws {
        let source = """
            protocol Refreshing {
                var stamp: Int { get }
                func refresh()
                func reload()
                subscript(key: String) -> Int { get }
            }
            class Feed: Refreshing {
                init() {}
                func reload() {}
            }
            extension Feed {
                static let cache = makeCache()
                var stamp: Int { 0 }
                func refresh() {}
                subscript(key: String) -> Int { 0 }
            }
            class Other: Refreshing {
                init() {}
                var stamp: Int { 0 }
                func refresh() {}
                func reload() {}
                subscript(key: String) -> Int { 0 }
            }
            """
        var output = ""
        let printed = try await capturingOutput {
            output = try await generateMocks(source: source)
        }
        // The extension's members are only read for what they hide: one whose type can't be inferred doesn't warn.
        #expect(!printed.contains("cache"))
        let feedStart = try #require(output.firstRange(of: "class MockFeed"))
        let otherStart = try #require(output.firstRange(of: "class MockOther"))
        let feed = String(output[feedStart.lowerBound..<otherStart.lowerBound])
        #expect(feed.contains("override func reload()"))
        #expect(!feed.contains("func refresh()"))
        #expect(!feed.contains("var stamp: Int"))
        #expect(!feed.contains("subscript("))
        #expect(output[otherStart.lowerBound...].contains("override func refresh()"))
    }

    /// With a default isolation, a protocol refining a `nonisolated` one takes the default itself: its own
    /// requirements are isolated, and the ones it inherits aren't. Stated, `nonisolated` covers its own too.
    @Test
    func aProtocolRefiningANonisolatedOneTakesTheDefaultIsolation() async throws {
        let source = """
            nonisolated protocol Anywhere {
                func anywhere()
            }
            protocol Refining: Anywhere {
                func refined()
            }
            nonisolated protocol StatedRefining: Anywhere {
                func stated()
            }
            """
        let output = try await generateMocks(source: source, options: Self.mainActor)
        let start = try #require(output.firstRange(of: "class MockRefining"))
        let end = try #require(output.firstRange(of: "class MockStatedRefining"))
        let mock = String(output[start.lowerBound..<end.lowerBound])
        #expect(!output.contains("nonisolated final class MockRefining"))
        #expect(mock.contains("    nonisolated\n    func anywhere()"))
        #expect(mock.contains("\n\n    func refined()"))
        #expect(mock.contains("@MainActor\n        @discardableResult\n        func refined() -> Cuckoo.VerifiedCall"))
        #expect(output.contains("nonisolated final class MockStatedRefining"))
    }

    /// `Self.Key` next to a member's generic parameter `Key` is the mock's `__CuckooSelf_Key`, a typealias of `Key`
    /// that nothing shadows, generic like the typealias it stands for.
    @Test
    func aTypealiasShadowedByAGenericParameterIsNamedThroughATypealias() async throws {
        let source = """
            protocol Storing {
                typealias Key = String
                func get<Key>(_ key: Key) -> [Self.Key]
            }
            protocol Caching {
                associatedtype Item
                typealias Key = [Int]
                typealias Pair<T: Hashable, U> = (T, U)
                func get<Key>(_ key: Key) -> Self.Key.Element
                func pair<Pair>(_ pair: Pair) -> Self.Pair<Int, Item>
                func tag<Tag>(_ tag: Tag) -> Self.Tag<Int>
            }
            extension Caching {
                typealias Tag<T> = [T]
            }
            """
        let output = try await generateMocks(source: source)
        #expect(output.contains("func get<Key> (_ p0: Key) -> [__CuckooSelf_Key] {"))
        #expect(output.contains("func get<Key> (_ p0: Key) -> __CuckooSelf_Key.Element {"))
        #expect(output.contains("func pair<Pair> (_ p0: Pair) -> __CuckooSelf_Pair<Int, Item> {"))
        #expect(output.contains("    typealias __CuckooSelf_Key = Key\n"))
        #expect(output.contains("    typealias __CuckooSelf_Pair<T, U> = Pair<T, U>\n"))
        // An extension's typealias is only known by the arguments it's given.
        #expect(output.contains("    typealias __CuckooSelf_Tag<__T1> = Tag<__T1>\n"))
        #expect(!output.contains("Self.Key"))
        #expect(!output.contains("Self.Pair"))
    }

    /// The stubbing and the verification proxy agree on which overloads are a pair: the ones a call of the proxy's
    /// member can't tell apart, whatever they return and whatever their access or isolation.
    @Test
    func theProxiesPairTheSameOverloads() async throws {
        let source = """
            public class Loader {
                public init() {}
                public func value() -> Int { 0 }
                func value() async -> String { "" }
                func shared() -> Int { 0 }
                @MainActor public func shared() async -> Int { 0 }
                func load(_ id: Int) -> Int { 0 }
                func load(_ id: String) async -> Int { 0 }
            }
            """
        let output = try await generateMocks(source: source)
        #expect(output.split(separator: "public var async: __Async {").count == 3)
        // In each proxy's `async`: `value()` and `shared()`, and not `load(_:)`, whose overloads take different types.
        let stubbing = try #require(output.firstRange(of: "struct __StubbingProxy_Loader"))
        let verification = try #require(output.firstRange(of: "struct __VerificationProxy_Loader"))
        let stub = try #require(output.firstRange(of: "class LoaderStub"))
        for proxy in [String(output[stubbing.lowerBound..<verification.lowerBound]), String(output[verification.lowerBound..<stub.lowerBound])] {
            let namespace = try #require(proxy.firstRange(of: "struct __Async {").map { String(proxy[$0.lowerBound...]) })
            #expect(namespace.contains("func value() -> Cuckoo."))
            #expect(namespace.contains("func shared() -> Cuckoo."))
            #expect(!namespace.contains("func load"))
            #expect(!proxy.contains("async -> Cuckoo."))
        }
    }

    /// A subclass that states a protocol doesn't declare the requirements its superclass implements with members no
    /// mock can override, in its body or in an extension. A generic superclass is found without its arguments.
    @Test
    func aRequirementASuperclassImplementsUnoverridablyIsNotMocked() async throws {
        let source = """
            protocol Resetting {
                static func reset()
                func ping()
                func hello()
                func open()
            }
            class Base {
                init() {}
                static func reset() {}
                final func ping() {}
                func open() {}
            }
            extension Base {
                func hello() {}
            }
            class Child: Base, Resetting {}
            class GenericBase<Value> {
                init() {}
                static func reset() {}
                final func ping() {}
                final func open() {}
            }
            extension GenericBase {
                func hello() {}
            }
            class GenericChild: GenericBase<Int>, Resetting {}
            """
        let output = try await generateMocks(source: source)
        let childStart = try #require(output.firstRange(of: "class MockChild"))
        let genericBaseStart = try #require(output.firstRange(of: "class MockGenericBase"))
        let genericChildStart = try #require(output.firstRange(of: "class MockGenericChild"))
        let child = String(output[childStart.lowerBound..<genericBaseStart.lowerBound])
        #expect(child.contains("override func open()"))
        for mock in [child, String(output[genericChildStart.lowerBound...])] {
            #expect(!mock.contains("func reset()"))
            #expect(!mock.contains("func ping()"))
            #expect(!mock.contains("func hello()"))
        }
        #expect(!output[genericChildStart.lowerBound...].contains("func open()"))
    }

    /// An `override` in an extension, which Swift allows for an `@objc dynamic` member, hides nothing: the mock
    /// overrides the superclass's member again.
    @Test
    func anOverrideInAnExtensionIsStillMocked() async throws {
        let source = """
            import Foundation
            class DynamicBase: NSObject {
                @objc dynamic func refresh() {}
            }
            class DynamicChild: DynamicBase {}
            extension DynamicChild {
                override func refresh() {}
            }
            """
        let output = try await generateMocks(source: source)
        let child = try #require(output.firstRange(of: "class MockDynamicChild").map { String(output[$0.lowerBound...]) })
        #expect(child.contains("override func refresh()"))
    }

    /// A generic member's default implementation is called on the opened existential, where a typealias of a
    /// non-primary associated type is another type, cast like the associated type itself. A typealias of a primary
    /// one is the same type, and the member's own generic parameter of the name is no typealias.
    @Test
    func aTypealiasOfAnAssociatedTypeIsCastForTheOpenedExistential() async throws {
        let source = """
            protocol Keyed<Key> {
                associatedtype Key
                associatedtype Value
                typealias Keys = [Key]
                typealias Values = [Value]
                typealias Grid = [Values]
                func keys<T>(_ value: T) -> Keys
                func values<T>(_ value: T, for values: Values) -> Grid
                func shadowed<Values>(_ value: Values) -> Keys
            }
            """
        let output = try await generateMocks(source: source)
        #expect(output.contains("return opened.values(p0, for: p1 as! _CUCKOO$$GENERIC.Values) as! Grid"))
        #expect(!output.contains("opened.keys"))
        #expect(!output.contains("opened.shadowed"))
    }

    /// A class's member that writes `Self` or an associated type as a concrete type implements the requirement, so
    /// the class's mock overrides it and doesn't declare the requirement again; one that differs elsewhere doesn't.
    @Test
    func aMemberWritingAPlaceholderAsAConcreteTypeImplementsTheRequirement() async throws {
        let source = """
            protocol Producing {
                associatedtype Output: Collection
                func make() -> Output
                func first(of output: Self.Output) -> Output.Element?
                func same(_ other: Self) -> Bool
                func put(_ value: Output, count: Int)
            }
            class Maker: Producing {
                init() {}
                func make() -> [Int] { [] }
                func first(of output: [Int]) -> Int? { nil }
                func same(_ other: Maker) -> Bool { true }
                func put(_ value: [Int], count: String) {}
            }
            """
        let output = try await generateMocks(source: source)
        let start = try #require(output.firstRange(of: "class MockMaker:")).lowerBound
        let end = try #require(output.firstRange(of: "class MakerStub:")).lowerBound
        let classMock = output[start..<end]
        #expect(classMock.contains("override func make() -> [Int] {"))
        #expect(classMock.contains("override func first(of p0: [Int]) -> Int? {"))
        #expect(classMock.contains("override func same(_ p0: Maker) -> Bool {"))
        #expect(!classMock.contains("func make() -> Output {"))
        #expect(!classMock.contains("-> Output.Element? {"))
        #expect(!classMock.contains("func same(_ p0: __CuckooSelf)"))
        // `count: String` isn't `count: Int`: the requirement is declared next to the class's member.
        #expect(classMock.contains("func put(_ p0: Output, count p1: Int) {"))
    }

    /// A placeholder stands for one whole type, the same one wherever the requirement writes it, `Self` for the class
    /// and an associated type for the type the class's typealias gives it.
    @Test
    func aPlaceholderStandsForOneWholeType() async throws {
        let source = """
            protocol Pairing {
                associatedtype Output
                func f(_ a: (Output, Int))
                func h(_ c: (Output) -> Void)
                func k(_ a: Output, _ b: Output)
                func m(_ a: Output)
                func same(_ other: Self) -> Bool
            }
            class Pairer: Pairing {
                typealias Output = Int
                init() {}
                func f(_ a: (Int, String, Int)) {}
                func h(_ c: (Int, Int) -> Void) {}
                func k(_ a: Int, _ b: String) {}
                func m(_ a: String) {}
                func same(_ other: Int) -> Bool { true }
            }
            """
        let output = try await generateMocks(source: source)
        let start = try #require(output.firstRange(of: "class MockPairer:")).lowerBound
        let end = try #require(output.firstRange(of: "class PairerStub:")).lowerBound
        let classMock = output[start..<end]
        #expect(classMock.contains("    func f(_ p0: (Output, Int)) {"))
        #expect(classMock.contains("    func h(_ p0: (Output) -> Void) {"))
        #expect(classMock.contains("    func k(_ p0: Output, _ p1: Output) {"))
        #expect(classMock.contains("    func m(_ p0: Output) {"))
        // `Int` isn't the class: the requirement, which the mock can't declare, is left out.
        #expect(classMock.contains("    // - 'same(_:)' names `Self` and is left to the protocol's default implementation, which calls run."))
    }

    /// A `where` clause naming an associated type is matched as the member's types are, the same type for each use.
    @Test
    func aWhereClauseNamingAnAssociatedTypeIsMatched() async throws {
        let source = """
            protocol Picking {
                associatedtype Key
                func pick<T>(_ values: T) -> Key? where T: Sequence, T.Element == Key
                func first<T>(_ values: T) -> Key? where T: Sequence, T.Element == Key
            }
            class Picker: Picking {
                typealias Key = String
                init() {}
                func pick<T>(_ values: T) -> String? where T: Sequence, T.Element == String { nil }
                func first<T>(_ values: T) -> String? where T: Sequence, T.Element == Int { nil }
            }
            """
        let output = try await generateMocks(source: source)
        let start = try #require(output.firstRange(of: "class MockPicker:")).lowerBound
        let end = try #require(output.firstRange(of: "class PickerStub:")).lowerBound
        let classMock = output[start..<end]
        #expect(classMock.contains("override func pick<T> (_ p0: T) -> String? where T: Sequence, T.Element == String {"))
        #expect(!classMock.contains("func pick<T> (_ p0: T) -> Key? where T: Sequence, T.Element == Key {"))
        // `Int` isn't the `String` the class's typealias makes `Key`.
        #expect(classMock.contains("func first<T> (_ p0: T) -> Key? where T: Sequence, T.Element == Key {"))
    }

    /// A protocol's typealias is matched as what it stands for, and a class's typealiases, one of another too, narrow
    /// what a placeholder stands for, with a member path as `Output.Type`.
    @Test
    func typealiasesAreMatchedAsWhatTheyStandFor() async throws {
        let source = """
            protocol Listing {
                associatedtype Item
                typealias Items = [Item]
                func all() -> Items
                func first(_ items: Self.Items) -> Item?
                func pair(_ first: Item, _ second: Item)
                func accept(_ type: Item.Type)
            }
            class Lister: Listing {
                typealias Number = Int
                typealias Item = Number
                init() {}
                func all() -> [Int] { [] }
                func first(_ items: [Item]) -> Int? { nil }
                func pair(_ first: Item, _ second: Int) {}
                func accept(_ type: String) {}
            }
            """
        let output = try await generateMocks(source: source)
        let start = try #require(output.firstRange(of: "class MockLister:")).lowerBound
        let end = try #require(output.firstRange(of: "class ListerStub:")).lowerBound
        let classMock = output[start..<end]
        #expect(classMock.contains("override func all() -> [Int] {"))
        #expect(!classMock.contains("func all() -> Items {"))
        #expect(!classMock.contains("func first(_ p0: Self.Items) -> Item? {"))
        #expect(!classMock.contains("func pair(_ p0: Item, _ p1: Item) {"))
        // `String` isn't `Int.Type`: the requirement is declared next to the class's member.
        #expect(classMock.contains("    func accept(_ p0: Item.Type) {"))
    }

    /// A requirement naming `Self` that the class leaves to the protocol's default implementation isn't declared in
    /// the class's mock, which says so; one the class implements is overridden.
    @Test
    func aSelfRequirementLeftToADefaultIsntMocked() async throws {
        let source = """
            protocol Merging {
                func merged(with other: Self) -> Bool
                func copy() -> Self
                func describe(_ value: Self.Type) -> String
                func kind(_ type: Self.Type) -> Int
            }
            extension Merging {
                func merged(with other: Self) -> Bool { false }
                func copy() -> Self { self }
                func kind(_ type: Self.Type) -> Int { 0 }
            }
            class OwnMerger: Merging {
                init() {}
                func merged(with other: OwnMerger) -> Bool { true }
                func describe(_ value: OwnMerger.Type) -> String { "" }
            }
            """
        let output = try await generateMocks(source: source)
        let start = try #require(output.firstRange(of: "class MockOwnMerger:")).lowerBound
        let end = try #require(output.firstRange(of: "class OwnMergerStub:")).lowerBound
        let classMock = output[start..<end]
        #expect(classMock.contains("override func merged(with p0: OwnMerger) -> Bool {"))
        #expect(classMock.contains("override func describe(_ p0: OwnMerger.Type) -> String {"))
        #expect(classMock.contains("    // - 'copy()' names `Self` and is left to the protocol's default implementation, which calls run."))
        #expect(classMock.contains("    // - 'kind(_:)' names `Self` and is left to the protocol's default implementation, which calls run."))
        #expect(!classMock.contains("func copy() -> Self {"))
    }

    /// A member type of an associated type the class names, as `Output.Element`, is one the class writes as it likes,
    /// and a placeholder on a constraint's left side is matched whatever order the constraints sort in.
    @Test
    func memberPathsAndConstraintOrderAreMatched() async throws {
        let source = """
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
            """
        let output = try await generateMocks(source: source)
        let start = try #require(output.firstRange(of: "class MockIntIndex:")).lowerBound
        let end = try #require(output.firstRange(of: "class IntIndexStub:")).lowerBound
        let classMock = output[start..<end]
        #expect(classMock.contains("override func first() -> Int? {"))
        #expect(!classMock.contains("-> Output.Element? {"))
        #expect(!classMock.contains("where Value == T.Element, Key == U.Element {"))
    }

    /// With a default isolation, a `nonisolated` class's member takes its requirement's actor only when it's the
    /// requirement's witness: the overload written with the class's typealias type, not the other one.
    @Test
    func onlyTheWitnessTakesTheRequirementsActor() async throws {
        let source = """
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
            """
        let output = try await generateMocks(source: source, options: Self.mainActor)
        #expect(output.contains("    @MainActor\n    override func display(_ p0: Int) {"))
        #expect(output.contains("    override func display(_ p0: String) {"))
        #expect(!output.contains("    @MainActor\n    override func display(_ p0: String) {"))
    }
}
