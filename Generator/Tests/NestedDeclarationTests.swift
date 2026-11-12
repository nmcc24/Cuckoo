import Testing
@testable import CuckooGenerator

/// How a type's declaration context reaches its mock: generic parameters, enclosing types and access levels.
@Suite
struct NestedDeclarationTests {
    @Test
    func valueGenericsKeepLet() async throws {
        let output = try await generateMocks(source: """
            class Buffer<let Count: Int> {
                func first<let N: Int>(_ count: Int) -> Int { 0 }
            }
            """)
        #expect(output.contains("class MockBuffer<let Count: Int>: Buffer<Count>"))
        #expect(output.contains("override func first<let N: Int> (_ p0: Int) -> Int"))
    }
}
