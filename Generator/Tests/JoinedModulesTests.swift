import Foundation
import Testing
@testable import CuckooGenerator

/// Modules with the same output file, as every module has under the single-file build plugin, are joined into it:
/// all their mocks, with the imports of all of them once, at the top.
@Suite
struct JoinedModulesTests {
    @Test
    func modulesSharingAnOutputAreJoined() async throws {
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent("CuckooJoined-\(UUID().uuidString)")
        defer { try? FileManager.default.removeItem(at: directory) }
        let files = [
            "App/Screen.swift": "import Foundation\n\nprotocol Screen {\n    func show()\n}\n",
            "Core/Store.swift": "public protocol Store {\n    func load() -> Int\n}\n",
        ]
        for (path, source) in files {
            let url = directory.appendingPathComponent(path)
            try FileManager.default.createDirectory(at: url.deletingLastPathComponent(), withIntermediateDirectories: true)
            try source.write(to: url, atomically: true, encoding: .utf8)
        }
        let modules = try Cuckoofile.modules(
            from: """
                [modules.App]
                testableImports = ["Cuckoo", "App"]
                sources = { App = ["App/*.swift"] }
                [modules.App.options]
                omitHeaders = true

                [modules.Core]
                testableImports = ["Cuckoo", "Core"]
                sources = { Core = ["Core/*.swift"] }
                [modules.Core.options]
                omitHeaders = true
                """,
            configurationPath: Path(directory.appendingPathComponent("Cuckoofile.toml").path),
            overriddenOutput: "/derived/GeneratedMocks.swift",
            requestedModuleName: nil
        )
        let output = try await Generator.generateJoined(for: modules, verbose: false)

        #expect(output.contains("class MockScreen"))
        #expect(output.contains("class MockStore"))
        let lines = output.components(separatedBy: "\n")
        let importLines = lines.filter { $0.contains("import ") }
        // Every import comes once, before the first mock.
        #expect(Set(importLines).count == importLines.count)
        let firstMock = try #require(lines.firstIndex { $0.contains("class Mock") })
        #expect(lines.lastIndex { $0.contains("import ") }! < firstMock)
        // Core's mock is public, so Cuckoo and Core are imported publicly; App's, internal, stays a plain import.
        #expect(importLines == [
            "import Foundation",
            "@testable public import Cuckoo",
            "@testable import App",
            "@testable public import Core",
            "@testable import protocol App.Screen",
            "@testable public import protocol Core.Store",
        ])
    }
}
