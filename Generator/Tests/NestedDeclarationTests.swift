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

    @Test
    func aTypeInAPublicExtensionIsPublic() async throws {
        let output = try await generateMocks(source: """
            public class Outer {}
            public extension Outer {
                class Inner {
                    public func run() {}
                }
            }
            public class Other {
                class Hidden {}
            }
            """)
        #expect(output.contains("public final class MockInner: Inner,"))
        #expect(output.contains("    final class MockHidden: Hidden,"))
        #expect(!output.contains("public final class MockHidden"))
    }

    @Test
    func aTypeInAPrivateExtensionIsSkipped() async throws {
        let output = try await generateMocks(source: """
            class Outer {}
            private extension Outer {
                class Inner {}
            }
            """)
        #expect(!output.contains("MockInner"))
    }
}
