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

    /// An async method's stubbing and verification members are `async` when a sync overload would otherwise be
    /// called the same way, and only then.
    @Test
    func anAsyncOverloadOfASyncMethodIsStubbedWithAwait() async throws {
        let source = """
            protocol Loading {
                func value() -> Int
                func value() async -> Int
                func load(_ id: Int) async -> Int
                func load(_ id: String) -> Int
            }
            """
        let output = try await generateMocks(source: source)
        #expect(output.contains("func value() -> Cuckoo.ProtocolStubFunction<(), Int, (()) -> Int,"))
        // On the caller's actor, which keeps a proxy that isn't `Sendable` there.
        #expect(output.contains("nonisolated(nonsending) func value() async -> Cuckoo.ProtocolStubFunction<(), Int, nonisolated(nonsending) (()) async -> Int,"))
        #expect(output.contains("nonisolated(nonsending) func value() async -> Cuckoo.VerifiedCall<(), Int>"))
        // Different parameters tell these apart already.
        #expect(!output.contains("(_ p0: __M1) async ->"))
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

    /// `Self.Key` next to a member's generic parameter `Key` is named through the mock's type, or written out in a
    /// generic mock, whose type would bring its associated types into the member's.
    @Test
    func aTypealiasShadowedByAGenericParameterIsNamedThroughTheMock() async throws {
        let source = """
            protocol Storing {
                typealias Key = String
                func get<Key>(_ key: Key) -> [Self.Key]
            }
            protocol Caching {
                associatedtype Item
                typealias Key = [Int]
                func get<Key>(_ key: Key) -> Self.Key.Element
            }
            """
        let output = try await generateMocks(source: source)
        #expect(output.contains("func get<Key> (_ p0: Key) -> [MockStoring.Key] {"))
        #expect(output.contains("func get<Key> (_ p0: Key) -> ([Int]).Element {"))
    }
}
