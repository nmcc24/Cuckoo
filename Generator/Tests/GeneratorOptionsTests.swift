import Foundation
import Testing
#if canImport(CuckooGenerator)
@testable import CuckooGenerator
#endif

/// What the Cuckoofile options do to the generated mocks. The fixture matrix and the runtime tests compile the
/// results; these pin the generated text.
@Suite
struct GeneratorOptionsTests {
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
        #expect(output.contains("final class ServiceStub:Service"))
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
        let imports = output.components(separatedBy: "\n").filter { $0.hasSuffix("import Foundation") || $0.hasSuffix("import App") || $0.hasSuffix("import Dispatch") || $0.hasSuffix("import Cuckoo") }
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
            }
            nonisolated protocol Clock {
                func now() -> Int
            }
            """
        let isolated = try await generate(source: source, options: #"defaultIsolation = "MainActor""#)
        #expect(isolated.contains("@MainActor final class DefaultImplCaller: Store {"))
        #expect(isolated.contains("@MainActor func enableDefaultImplementation<"))
        #expect(isolated.contains("final class MockStore<Key: Hashable>: Store,"))
        #expect(!isolated.contains("nonisolated final class MockStore"))
        // A protocol that opts out stays nonisolated.
        #expect(isolated.contains("nonisolated final class MockClock"))

        let plain = try await generate(source: source, options: #"defaultIsolation = "nonisolated""#)
        #expect(plain == (try await generate(source: source)))
        #expect(plain.contains("nonisolated final class DefaultImplCaller: Store, @unchecked Sendable {"))
    }

    @Test
    func defaultIsolationIsValidated() async throws {
        let error = await #expect(throws: (any Error).self) {
            try await generate(source: "protocol Store {}", options: #"defaultIsolation = "@MainActor""#)
        }
        #expect(String(describing: try #require(error)).contains(#"use "MainActor" or "nonisolated""#))
    }

    private func occurrences(of text: String, in output: String) -> Int {
        output.components(separatedBy: text).count - 1
    }

    private func generate(source: String, moduleKeys: String = "", options: String = "") async throws -> String {
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent("CuckooOptions-\(UUID().uuidString)")
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: directory) }
        try source.write(to: directory.appendingPathComponent("Source.swift"), atomically: true, encoding: .utf8)
        let modules = try Cuckoofile.modules(
            from: """
                [modules.App]
                sources = ["Source.swift"]
                output = "Mocks.swift"
                \(moduleKeys)

                [modules.App.options]
                omitHeaders = true
                \(options)
                """,
            configurationPath: Path(directory.appendingPathComponent("Cuckoofile.toml").path),
            overriddenOutput: nil,
            requestedModuleName: nil
        )
        let module = try #require(modules.first)
        return try await Generator.generate(for: module, singleFileOutput: true, verbose: false)
            .map(\.contents)
            .joined(separator: "\n")
    }
}
