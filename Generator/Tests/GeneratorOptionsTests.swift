import Foundation
import Testing
@testable import CuckooGenerator

/// What the Cuckoofile options do to the generated mocks. The fixture matrix and the runtime tests compile the
/// results; these pin the generated text.
@Suite
struct GeneratorOptionsTests {
    @Test
    func protocolsOnlySkipsClasses() async throws {
        let source = "protocol Service {}\nclass Store {}"
        let output = try await generate(source: source, options: "protocolsOnly = true")
        #expect(output.contains("class MockService"))
        #expect(!output.contains("MockStore"))
        #expect(try await generate(source: source).contains("class MockStore"))
    }

    @Test
    func inheritanceCanBeTurnedOff() async throws {
        let source = """
            protocol Base {
                func base()
            }
            protocol Derived: Base {
                func derived()
            }
            """
        // Each mock spells a member in its mock, stubbing proxy, verification proxy and stub: MockDerived repeats
        // Base's members only with inheritance on.
        let inherited = try await generate(source: source)
        let flat = try await generate(source: source, options: "enableInheritance = false")
        #expect(occurrences(of: "func base()", in: flat) > 0)
        #expect(occurrences(of: "func base()", in: inherited) == 2 * occurrences(of: "func base()", in: flat))
        #expect(occurrences(of: "func derived()", in: inherited) == occurrences(of: "func derived()", in: flat))
    }

    @Test
    func regexKeepsTypesMatchingAnyPattern() async throws {
        let output = try await generate(
            source: """
                protocol UserService {}
                protocol UserRepository {}
                protocol Clock {}
                """,
            moduleKeys: #"regex = ["Service$", "^UserRepo"]"#
        )
        #expect(output.contains("class MockUserService"))
        #expect(output.contains("class MockUserRepository"))
        #expect(!output.contains("MockClock"))
    }

    @Test
    func singleRegexStillWorks() async throws {
        let output = try await generate(source: "protocol UserService {}\nprotocol Clock {}", moduleKeys: #"regex = "Service$""#)
        #expect(output.contains("class MockUserService"))
        #expect(!output.contains("MockClock"))
    }

    @Test
    func mockPrefixAndSuffixNameEveryReference() async throws {
        let output = try await generate(
            source: """
                protocol Service {
                    var name: String { get }
                    func run(_ value: Int) -> Int
                    static func make() -> Self
                }
                actor Worker {}
                protocol Store: Actor {
                    func load() -> Int
                }
                """,
            options: """
                mockPrefix = "Fake"
                mockSuffix = "Double"
                """
        )
        #expect(output.contains("final class FakeServiceDouble: Service,"))
        #expect(output.contains("actor FakeStoreDouble: Store,"))
        #expect(output.contains("typealias __CuckooSelf = FakeServiceDouble"))
        #expect(output.contains("cuckoo_manager.createStub(for: FakeServiceDouble.self,"))
        #expect(output.contains("final class ServiceStub: Service"))
        #expect(!output.contains("MockService"))
        #expect(!output.contains("MockStore"))
    }

    /// Brightify/Cuckoo#561: the mocked module is imported with every `@_spi` group its mocked declarations use,
    /// because a testable import doesn't make SPI visible, and a public mock repeats `@_spi` wherever it's public.
    @Test
    func spiGroupsReachTheImportsAndThePublicMocks() async throws {
        let output = try await generate(
            source: """
                @_spi(Tools) import Foundation
                import Dispatch

                @_spi(Internal) public struct Token {}

                public protocol Service {
                    func open()
                    @_spi(Internal) func secret(_ token: Token)
                }

                @_spi(Admin) public protocol AdminService {
                    func reset()
                }

                internal protocol Plain {
                    func run()
                }
                """,
            moduleKeys: #"testableImports = ["App"]"#
        )
        let imports = output.lines.filter { $0.hasSuffix("import Foundation") || $0.hasSuffix("import App") || $0.hasSuffix("import Dispatch") || $0.hasSuffix("import Cuckoo") }
        #expect(imports == [
            "public import Cuckoo",
            "@_spi(Tools) import Foundation",
            "import Dispatch",
            "@_spi(Internal) @_spi(Admin) @testable public import App",
        ])
        // The mock and the nop stub declare the member public. (Fixture 28 compiles the default implementation
        // caller's copy.)
        #expect(occurrences(of: "@_spi(Internal)\n    public func secret(_ p0: Token)", in: output) == 2)
        // The proxies' members are internal, and can't be SPI.
        #expect(!output.contains("@_spi(Internal)\n    func secret"))
        #expect(output.contains("@_spi(Admin)\npublic nonisolated final class MockAdminService"))
        #expect(output.contains("@_spi(Admin)\npublic nonisolated final class AdminServiceStub"))
        #expect(!output.contains("@_spi(Admin)\n    public func reset"))
    }

    /// `defaultIsolation = "MainActor"` gives the types that state no isolation the module's default, as the
    /// compiler does, so a generic protocol's default-implementation wrapper is isolated like the protocol.
    @Test
    func defaultIsolationIsolatesUnannotatedTypes() async throws {
        let source = """
            protocol Store {
                associatedtype Key: Hashable
                func value(for key: Key) -> Int
                func load<T>(_ hint: T) async -> Key
            }
            nonisolated protocol Clock {
                func now() -> Int
            }
            """
        let isolated = try await generate(source: source, options: #"defaultIsolation = "MainActor""#)
        // The members see their protocol's isolation too: a MainActor member's local function is isolated to it,
        // so it doesn't get Swift 6.2's `nonisolated(nonsending)` workaround.
        #expect(!isolated.contains("nonisolated(nonsending) func openExistential"))
        #expect(isolated.contains("@MainActor final class DefaultImplCaller: Store {"))
        #expect(isolated.contains("@MainActor func enableDefaultImplementation<"))
        #expect(isolated.contains("final class MockStore<Key: Hashable>: Store,"))
        #expect(!isolated.contains("nonisolated final class MockStore"))
        // A protocol that opts out stays nonisolated.
        #expect(isolated.contains("nonisolated final class MockClock"))

        let plain = try await generate(source: source, options: #"defaultIsolation = "nonisolated""#)
        #expect(plain == (try await generate(source: source)))
        #expect(plain.contains("nonisolated final class DefaultImplCaller: Store, Sendable {"))
        #expect(plain.contains("nonisolated(nonsending) func openExistential"))
    }

    @Test
    func defaultIsolationIsValidated() async throws {
        let error = await #expect(throws: (any Error).self) {
            try await generate(source: "protocol Store {}", options: #"defaultIsolation = "@MainActor""#)
        }
        #expect(String(describing: try #require(error)).contains(#"use "MainActor" or "nonisolated""#))
    }

    private func occurrences(of text: String, in output: String) -> Int {
        output.ranges(of: text).count
    }

    private func generate(source: String, moduleKeys: String = "", options: String = "") async throws -> String {
        try await generateMocks(source: source, moduleKeys: moduleKeys, options: options)
    }
}
