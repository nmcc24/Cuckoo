import ArgumentParser
import Foundation
import Testing
@testable import CuckooGenerator

/// The command line: where the Cuckoofile comes from, and a failed generation failing the run, so a build plugin
/// doesn't go on to compile stale or missing mocks.
@Suite
struct GenerateCommandTests {
    @Test
    func writesTheMocks() async throws {
        try await withPackage(output: "Mocks/GeneratedMocks.swift") { directory in
            try await GenerateCommand.parse(["--configuration", directory.appending(path: "Cuckoofile.toml").path(percentEncoded: false)]).run()
            let mocks = try String(contentsOf: directory.appending(path: "Mocks/GeneratedMocks.swift"), encoding: .utf8)
            #expect(mocks.contains("class MockGreeter"))
        }
    }

    @Test
    func failedWriteFailsTheRun() async throws {
        // The output's parent is a file, so its directory can't be created.
        try await withPackage(output: "Blocker/GeneratedMocks.swift") { directory in
            try "".write(to: directory.appending(path: "Blocker"), atomically: true, encoding: .utf8)
            await #expect(throws: ExitCode.failure) {
                try await GenerateCommand.parse(["--configuration", directory.appending(path: "Cuckoofile.toml").path(percentEncoded: false)]).run()
            }
        }
    }

    @Test
    func missingNamedConfigurationIsAnError() async throws {
        try await withPackage(output: "GeneratedMocks.swift") { directory in
            let missing = directory.appending(path: "Other.toml").path(percentEncoded: false)
            await #expect(throws: (any Error).self) {
                try await GenerateCommand.parse(["--configuration", missing]).run()
            }
        }
    }

    private func withPackage(output: String, _ body: (URL) async throws -> Void) async throws {
        let directory = FileManager.default.temporaryDirectory.appending(path: "CuckooCommand-\(UUID().uuidString)")
        defer { try? FileManager.default.removeItem(at: directory) }
        try FileManager.default.createDirectory(at: directory.appending(path: "App"), withIntermediateDirectories: true)
        try "protocol Greeter {\n    func greet() -> String\n}\n"
            .write(to: directory.appending(path: "App/Greeter.swift"), atomically: true, encoding: .utf8)
        try """
            [modules.App]
            output = "\(output)"
            testableImports = ["App"]
            sources = ["App/*.swift"]
            """
            .write(to: directory.appending(path: "Cuckoofile.toml"), atomically: true, encoding: .utf8)
        try await body(directory)
    }
}
