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
