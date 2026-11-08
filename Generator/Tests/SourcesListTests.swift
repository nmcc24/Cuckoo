import Foundation
import Testing
@testable import CuckooGenerator

/// The build plugins pass the files of the targets they generate for with `--sources-list`. A module without
/// `sources` mocks the files of the target with its name, or all of them; one with `sources` keeps its own. The SwiftPM runtime suite runs it
/// end to end through `CuckooPlugin` (`CuckooPluginTestSources`).
@Suite
struct SourcesListTests {
    @Test
    func listIsReadOnePathPerLine() throws {
        try withDirectory { directory in
            let list = directory.appending(path: "Sources.txt")
            try "/abs/A.swift\r\n\nApp\trelative/B.swift\n\t/abs/C.swift\n".write(to: list, atomically: true, encoding: .utf8)
            #expect(try GenerateCommand.sourcesList(at: list.path(percentEncoded: false)) == [
                Module.PluginSource(path: Path("/abs/A.swift"), swiftModule: nil),
                Module.PluginSource(path: (Path.current + Path("relative/B.swift")).standardized, swiftModule: "App"),
                Module.PluginSource(path: Path("/abs/C.swift"), swiftModule: nil),
            ])
        }
    }

    /// The plugins pass a short listing as `--source` arguments, in the form of the list's lines.
    @Test
    func sourceArgumentsAreReadLikeListLines() {
        #expect(["App\t/abs/A.swift", "/abs/B.swift"].map(GenerateCommand.pluginSource(fromLine:)) == [
            Module.PluginSource(path: Path("/abs/A.swift"), swiftModule: "App"),
            Module.PluginSource(path: Path("/abs/B.swift"), swiftModule: nil),
        ])
    }

    @Test
    func unreadableListIsReported() {
        let error = #expect(throws: (any Error).self) {
            try GenerateCommand.sourcesList(at: "/nonexistent/Sources.txt")
        }
        #expect(error.map(String.init(describing:))?.contains("Failed to read the sources list at '/nonexistent/Sources.txt'") == true)
    }

    /// Listed paths are files, not globs: `[1]` would otherwise be a character class that doesn't match itself.
    @Test
    func moduleWithoutSourcesMocksTheListedFiles() async throws {
        let output = try await generate(moduleKeys: "", listing: ["App/Screen[1].swift"])
        #expect(output.contains("class MockScreen"))
        #expect(!output.contains("class MockStore"))
        // The plugin names the module the files in its directory belong to.
        #expect(output.contains("@testable import protocol App.Screen"))
    }

    /// The runtime suite's single-file test plugin lists every dependency's files. A module named like one of them takes its files, and
    /// knows their module without the plugin naming one.
    @Test
    func moduleNamedLikeAListedModuleTakesItsFiles() async throws {
        let output = try await generate(
            moduleName: "Core",
            moduleKeys: "",
            listing: [("App", "App/Screen[1].swift"), ("Core", "Core/Store.swift")],
            sourceModule: false
        )
        #expect(output.contains("class MockStore"))
        #expect(!output.contains("class MockScreen"))
        #expect(output.contains("@testable import protocol Core.Store"))
    }

    @Test
    func moduleNamedLikeNoListedModuleTakesEveryFile() async throws {
        let output = try await generate(
            moduleKeys: "",
            listing: [("App", "App/Screen[1].swift"), ("Core", "Core/Store.swift")],
            sourceModule: false
        )
        #expect(output.contains("class MockStore"))
        #expect(output.contains("class MockScreen"))
        #expect(output.contains("@testable import protocol App.Screen"))
        #expect(output.contains("@testable import protocol Core.Store"))
    }

    @Test
    func moduleWithSourcesIgnoresTheList() async throws {
        let output = try await generate(moduleKeys: #"sources = ["Core/*.swift"]"#, listing: ["App/Screen[1].swift"])
        #expect(output.contains("class MockStore"))
        #expect(!output.contains("class MockScreen"))
    }

    @Test
    func withoutListOrSourcesNothingIsMocked() async throws {
        let output = try await generate(moduleKeys: "", listing: nil)
        #expect(output.isEmpty)
    }

    private func withDirectory<T>(_ body: (URL) throws -> T) rethrows -> T {
        let directory = FileManager.default.temporaryDirectory.appending(path: "CuckooSourcesList-\(UUID().uuidString)")
        try? FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: directory) }
        return try body(directory)
    }

    private func generate(moduleKeys: String, listing: [String]?) async throws -> String {
        try await generate(moduleKeys: moduleKeys, listing: listing?.map { (nil, $0) }, sourceModule: true)
    }

    private func generate(
        moduleName: String = "Mocks",
        moduleKeys: String,
        listing: [(String?, String)]?,
        sourceModule: Bool
    ) async throws -> String {
        let directory = FileManager.default.temporaryDirectory.appending(path: "CuckooSourcesList-\(UUID().uuidString)")
        defer { try? FileManager.default.removeItem(at: directory) }
        do {
            let files = [
                "App/Screen[1].swift": "protocol Screen {\n    func show()\n}\n",
                "Core/Store.swift": "protocol Store {\n    func load() -> Int\n}\n",
            ]
            for (path, source) in files {
                let url = directory.appending(path: path)
                try FileManager.default.createDirectory(at: url.deletingLastPathComponent(), withIntermediateDirectories: true)
                try source.write(to: url, atomically: true, encoding: .utf8)
            }
            let modules = try Cuckoofile.modules(
                from: """
                    [modules.\(moduleName)]
                    output = "Mocks.swift"
                    testableImports = ["App", "Core"]
                    \(moduleKeys)

                    [modules.\(moduleName).options]
                    omitHeaders = true
                    """,
                configurationPath: Path(directory.appending(path: "Cuckoofile.toml").path(percentEncoded: false)),
                overriddenOutput: nil,
                requestedModuleName: nil,
                sourceModule: sourceModule ? Module.SourceModule(name: "App", directory: Path(directory.appending(path: "App").path(percentEncoded: false))) : nil,
                pluginSources: listing.map { $0.map { Module.PluginSource(path: Path(directory.appending(path: $1).path(percentEncoded: false)), swiftModule: $0) } }
            )
            let module = try #require(modules.first)
            return try await Generator.generate(for: module, singleFileOutput: true, verbose: false)
                .map(\.contents)
                .joined(separator: "\n")
        }
    }
}
