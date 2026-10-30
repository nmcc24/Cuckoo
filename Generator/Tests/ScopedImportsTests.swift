import Foundation
import Testing
#if canImport(CuckooGenerator)
@testable import CuckooGenerator
#endif

/// Where the Swift module of the sources is known, the generated file imports each type they declare by name, so
/// the name means that type even where another import of the joined file declares the same name. The fixture
/// matrix and the runtime tests compile the results; these pin the generated text.
@Suite
struct ScopedImportsTests {
    private let files = [
        "App/Screen.swift": """
            import Foundation

            struct Namespace {}
            protocol Screen {
                func show(_ namespace: Namespace)
            }
            private struct Hidden {}
            fileprivate enum AlsoHidden {}
            """,
        "Core/Store.swift": """
            public protocol Store {
                func load() -> Int
            }
            actor Cache {}
            public typealias Key = String
            #if os(macOS)
            enum Platform {}
            #elseif DEBUG
            enum DebugPlatform {}
            #endif
            """,
    ]

    @Test
    func sourcesTableImportsEachTypeFromItsModule() async throws {
        let output = try await generate(
            moduleKeys: """
                sources = { App = ["App/*.swift"], Core = ["Core/*.swift"] }
                testableImports = ["App", "Core"]
                """
        )
        let joined = output.joined(separator: "\n\n")
        // `Store` is public, so its mock is, and the joined file imports every module publicly.
        #expect(scopedImports(in: joined) == [
            "@testable public import struct App.Namespace",
            "@testable public import protocol App.Screen",
            "@testable public import protocol Core.Store",
            "@testable public import class Core.Cache",
            "@testable public import typealias Core.Key",
            "#if (os(macOS))",
            "@testable public import enum Core.Platform",
            "#if !(os(macOS)) && (DEBUG)",
            "@testable public import enum Core.DebugPlatform",
        ])
        // A single file needs them once, however many sources it joins.
        #expect(output.count == 2)
        #expect(scopedImports(in: output[1]).isEmpty)
    }

    @Test
    func everyFileOfADirectoryOutputImportsTheTypes() async throws {
        let output = try await generate(
            moduleKeys: """
                sources = { App = ["App/*.swift"], Core = ["Core/*.swift"] }
                testableImports = ["App", "Core"]
                """,
            singleFileOutput: false
        )
        #expect(output.count == 2)
        for file in output {
            #expect(file.contains(" import struct App.Namespace\n"))
            #expect(file.contains(" import protocol Core.Store\n"))
        }
    }

    /// Without a testable import, only the public types are visible, and they're imported with the module's access level.
    @Test
    func plainImportsGetOnlyThePublicTypes() async throws {
        let output = try await generate(
            moduleKeys: """
                sources = { App = ["App/*.swift"], Core = ["Core/*.swift"] }
                imports = ["Core"]
                testableImports = ["App"]
                """
        )
        let lines = scopedImports(in: output.joined(separator: "\n\n"))
        #expect(lines.contains("import protocol Core.Store"))
        #expect(lines.contains("import typealias Core.Key"))
        #expect(!lines.contains { $0.contains("Core.Cache") || $0.contains("Core.Platform") })
    }

    /// A module the generated file doesn't import gets no scoped imports either.
    @Test
    func unimportedModulesAreLeftOut() async throws {
        let output = try await generate(
            moduleKeys: """
                sources = { App = ["App/*.swift"], Core = ["Core/*.swift"] }
                testableImports = ["App"]
                """
        )
        #expect(!output.joined().contains("Core."))
    }

    /// The build plugin names the module it generates for and its directory, through `CUCKOO_SOURCE_MODULE` and
    /// `CUCKOO_SOURCE_MODULE_DIRECTORY`. A listed file outside that directory belongs to another module, which
    /// the plugin can't name, so its types get no scoped imports.
    @Test
    func pluginSourceModuleCoversItsDirectory() async throws {
        let output = try await generate(
            moduleKeys: """
                sources = ["App/*.swift", "Core/*.swift"]
                testableImports = ["App"]
                imports = ["Core"]
                """,
            sourceModuleName: "App"
        )
        // `Store` is public, so its mock is, and the joined file imports App publicly.
        #expect(scopedImports(in: output.joined()) == [
            "@testable public import struct App.Namespace",
            "@testable public import protocol App.Screen",
        ])
    }

    /// Without a module, an array of sources generates what it always did.
    @Test
    func arrayWithoutModuleIsUnchanged() async throws {
        let output = try await generate(
            moduleKeys: """
                sources = ["App/*.swift", "Core/*.swift"]
                testableImports = ["App", "Core"]
                """
        )
        #expect(scopedImports(in: output.joined()).isEmpty)
    }

    private func scopedImports(in output: String) -> [String] {
        output.components(separatedBy: "\n").filter { line in
            line.hasPrefix("#if") || ["struct", "class", "enum", "protocol", "typealias"].contains { line.contains("import \($0) ") }
        }
    }

    private func generate(
        moduleKeys: String,
        sourceModuleName: String? = nil,
        singleFileOutput: Bool = true
    ) async throws -> [String] {
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent("CuckooScopedImports-\(UUID().uuidString)")
        defer { try? FileManager.default.removeItem(at: directory) }
        for (path, source) in files {
            let url = directory.appendingPathComponent(path)
            try FileManager.default.createDirectory(at: url.deletingLastPathComponent(), withIntermediateDirectories: true)
            try source.write(to: url, atomically: true, encoding: .utf8)
        }
        let modules = try Cuckoofile.modules(
            from: """
                [modules.Mocks]
                output = "Mocks.swift"
                \(moduleKeys)

                [modules.Mocks.options]
                omitHeaders = true
                """,
            configurationPath: Path(directory.appendingPathComponent("Cuckoofile.toml").path),
            overriddenOutput: nil,
            requestedModuleName: nil,
            sourceModule: sourceModuleName.map { Module.SourceModule(name: $0, directory: Path(directory.appendingPathComponent($0).path)) }
        )
        let module = try #require(modules.first)
        return try await Generator.generate(for: module, singleFileOutput: singleFileOutput, verbose: false).map(\.contents)
    }
}
