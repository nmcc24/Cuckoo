import Foundation
import Testing
@testable import CuckooGenerator

/// Modules with the same output file, as every module has under the runtime suite's single-file test plugin, are
/// joined into it:
/// all their mocks, with the imports of all of them once, at the top.
@Suite
struct JoinedModulesTests {
    @Test
    func modulesSharingAnOutputAreJoined() async throws {
        let directory = FileManager.default.temporaryDirectory.appending(path: "CuckooJoined-\(UUID().uuidString)")
        defer { try? FileManager.default.removeItem(at: directory) }
        let files = [
            "App/Screen.swift": "import Foundation\n\nprotocol Screen {\n    func show()\n}\n",
            "Core/Store.swift": "public protocol Store {\n    func load() -> Int\n}\n",
        ]
        for (path, source) in files {
            let url = directory.appending(path: path)
            try FileManager.default.createDirectory(at: url.deletingLastPathComponent(), withIntermediateDirectories: true)
            try source.write(to: url, atomically: true, encoding: .utf8)
        }
        let modules = try Cuckoofile.modules(
            from: """
                [modules.App]
                testableImports = ["Cuckoo", "App"]
                sources = { App = ["App/*.swift"] }

                [modules.Core]
                testableImports = ["Cuckoo", "Core"]
                sources = { Core = ["Core/*.swift"] }
                """,
            configurationPath: Path(directory.appending(path: "Cuckoofile.toml").path(percentEncoded: false)),
            overriddenOutput: "/derived/GeneratedMocks.swift",
            requestedModuleName: nil
        )
        let output = try await Generator.generateJoined(for: modules, verbose: false)

        #expect(output.contains("class MockScreen"))
        #expect(output.contains("class MockStore"))
        let lines = output.lines
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

    /// A parent qualified with another of the entry's source modules, `Core.Service` in `App`, which imports
    /// `Core`, is one of the sources: its members are merged, as an outside module's aren't.
    @Test
    func parentsQualifiedWithAnotherSourceModuleAreMerged() async throws {
        let directory = FileManager.default.temporaryDirectory.appending(path: "CuckooSourceModules-\(UUID().uuidString)")
        defer { try? FileManager.default.removeItem(at: directory) }
        let files = [
            "Core/Core.swift": "public protocol Service {\n    func fetch() -> Int\n}\n\nopen class Base {\n    public init() {}\n    open func work() -> Int { 0 }\n}\n",
            "App/App.swift": "import Core\n\npublic protocol AppService: Core.Service {\n    func extra()\n}\n\nopen class AppBase: Core.Base {}\n",
        ]
        for (path, source) in files {
            let url = directory.appending(path: path)
            try FileManager.default.createDirectory(at: url.deletingLastPathComponent(), withIntermediateDirectories: true)
            try source.write(to: url, atomically: true, encoding: .utf8)
        }
        let modules = try Cuckoofile.modules(
            from: """
                [modules.Mocks]
                sources = { Core = ["Core/*.swift"], App = ["App/*.swift"] }
                """,
            configurationPath: Path(directory.appending(path: "Cuckoofile.toml").path(percentEncoded: false)),
            overriddenOutput: "/derived/GeneratedMocks.swift",
            requestedModuleName: nil
        )
        let output = try await Generator.generateJoined(for: modules, verbose: false)
        func mock(_ name: String, until end: String) throws -> Substring {
            let start = try #require(output.firstRange(of: "class Mock\(name)"))
            let stop = try #require(output[start.upperBound...].firstRange(of: end))
            return output[start.lowerBound..<stop.lowerBound]
        }
        #expect(try mock("AppService", until: "class AppServiceStub").contains("func fetch() -> Int"))
        #expect(try mock("AppBase", until: "class AppBaseStub").contains("override func work() -> Int"))
    }

}
