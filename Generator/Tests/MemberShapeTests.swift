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
}
