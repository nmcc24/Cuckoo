import Testing
@testable import CuckooGenerator

/// How the mocks spell members whose isolation, type or overloads the generator has to work out. The fixture matrix
/// and the runtime tests compile the results; these pin the generated text, on Linux too for the Objective-C ones.
@Suite
struct MemberShapeTests {
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
        #expect(output.contains("func value() async -> Cuckoo.ProtocolStubFunction<(), Int, nonisolated(nonsending) (()) async -> Int,"))
        #expect(output.contains("func value() async -> Cuckoo.VerifiedCall<(), Int>"))
        // Different parameters tell these apart already.
        #expect(!output.contains("(_ p0: __M1) async ->"))
    }
}
