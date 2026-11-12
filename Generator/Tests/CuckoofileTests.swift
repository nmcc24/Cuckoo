import Foundation
import Testing
@testable import CuckooGenerator

/// Pins how `Cuckoofile.toml` is read: every key, how outputs fall back and override each other, module
/// filtering, and which configurations are rejected.
@Suite
struct CuckoofileTests {
    private static let repositoryRoot = URL(filePath: #filePath)
        .deletingLastPathComponent()
        .deletingLastPathComponent()
        .deletingLastPathComponent()

    private static let configurationPath = Path("/project/Cuckoofile.toml")

    private func parse(
        _ contents: String,
        configurationPath: Path = configurationPath,
        overriddenOutput: String? = nil,
        requestedModuleName: String? = nil
    ) throws -> [String: Module] {
        let modules = try Cuckoofile.modules(
            from: contents,
            configurationPath: configurationPath,
            overriddenOutput: overriddenOutput,
            requestedModuleName: requestedModuleName
        )
        return Dictionary(uniqueKeysWithValues: modules.map { ($0.name, $0) })
    }

    // MARK: Keys

    @Test
    func everyModuleKey() throws {
        let module = try #require(try parse("""
            [modules.App]
            imports = ["Foundation", " UIKit "]
            publicImports = ["Shared"]
            testableImports = ["App"]
            sources = ["Sources/App/**/*.swift", "/absolute/File.swift"]
            exclude = ["Excluded", "AlsoExcluded"]
            regex = "^Service"
            output = "Tests/Mocks"
            filenameFormat = "{}Mock"

            [modules.App.options]
            glob = false
            keepDocumentation = false
            enableInheritance = false
            protocolsOnly = true
            omitHeaders = true
            mockPrefix = "Fake"
            mockSuffix = "Double"
            """)["App"])

        #expect(module.imports == ["Foundation", "UIKit"])
        #expect(module.publicImports == ["Shared"])
        #expect(module.testableImports == ["App"])
        // Relative sources resolve against the Cuckoofile's folder; absolute ones are kept.
        #expect(module.sources?.map(\.rawValue) == ["/project/Sources/App/**/*.swift", "/absolute/File.swift"])
        #expect(module.exclude == ["Excluded", "AlsoExcluded"])
        #expect(module.regexes == ["^Service"])
        #expect(module.output == "Tests/Mocks")
        #expect(module.filenameFormat == "{}Mock")
        #expect(module.options.glob == false)
        #expect(module.options.keepDocumentation == false)
        #expect(module.options.enableInheritance == false)
        #expect(module.options.protocolsOnly == true)
        #expect(module.options.omitHeaders == true)
        #expect(module.options.mockNaming == MockNaming(prefix: "Fake", suffix: "Double"))
    }

    @Test
    func defaults() throws {
        let module = try #require(try parse("""
            [modules.App]
            output = "Mocks.swift"
            """)["App"])

        #expect(module.imports.isEmpty)
        #expect(module.publicImports.isEmpty)
        #expect(module.testableImports.isEmpty)
        #expect(module.sources == nil)
        #expect(module.exclude.isEmpty)
        #expect(module.regexes.isEmpty)
        #expect(module.filenameFormat == nil)
        #expect(module.options.glob == true)
        #expect(module.options.keepDocumentation == true)
        #expect(module.options.enableInheritance == true)
        #expect(module.options.protocolsOnly == false)
        #expect(module.options.omitHeaders == false)
        #expect(module.options.mockNaming == MockNaming(prefix: "Mock", suffix: ""))
    }

    /// `regex` takes one pattern or an array of them (Brightify/Cuckoo#535).
    @Test
    func regexArray() throws {
        let module = try #require(try parse("""
            [modules.App]
            output = "Mocks.swift"
            regex = ["^Service", "Repository$"]
            """)["App"])
        #expect(module.regexes == ["^Service", "Repository$"])
    }

    /// Mocks can be named `<prefix><Type><suffix>` (Brightify/Cuckoo#564).
    @Test
    func mockNamingWithSuffixOnly() throws {
        let module = try #require(try parse("""
            [modules.App]
            output = "Mocks.swift"
            [modules.App.options]
            mockPrefix = ""
            mockSuffix = "Mock"
            """)["App"])
        #expect(module.options.mockNaming.mockName(of: "Service") == "ServiceMock")
    }

    @Test(arguments: [
        ("\"\"", "\"\"", "can't both be empty"),
        ("\"\"", "\"Stub\"", "`<Type>Stub` classes"),
        ("\"Mock-\"", "\"\"", "letters, digits and underscores"),
        ("\"1Mock\"", "\"\"", "can't start with a digit"),
        ("\"Mock\"", "\" Fake\"", nil),
    ])
    func mockNamingIsValidated(prefix: String, suffix: String, error: String?) throws {
        let contents = """
            [modules.App]
            output = "Mocks.swift"
            [modules.App.options]
            mockPrefix = \(prefix)
            mockSuffix = \(suffix)
            """
        guard let error else {
            #expect(try parse(contents)["App"]?.options.mockNaming == MockNaming(prefix: "Mock", suffix: "Fake"))
            return
        }
        let thrown = try #require(throws: Cuckoofile.ParseError.self) { try parse(contents) }
        #expect(String(describing: thrown).contains(error))
    }

    @Test
    func unknownKeysAreIgnored() throws {
        let modules = try parse("""
            unknown = 1

            [modules.App]
            output = "Mocks.swift"
            somethingElse = "ignored"
            """)
        #expect(modules.keys.sorted() == ["App"])
    }

    /// Cuckoo 2's `xcodeproj` table is still read, so it can be reported with what to write instead.
    @Test
    func leftoverXcodeprojIsRejected() throws {
        let error = try #require(throws: Cuckoofile.ParseError.self) {
            try parse("""
                [modules.App]
                output = "Mocks.swift"
                [modules.App.xcodeproj]
                path = "Projects"
                target = "App"
                """)
        }
        #expect(String(describing: error).contains("The `xcodeproj` option was removed in Cuckoo 3."))
    }

    // MARK: Output

    @Test
    func globalOutputIsTheFallback() throws {
        let modules = try parse("""
            output = "Global.swift"

            [modules.Inherits]
            sources = []

            [modules.Own]
            output = "Own.swift"
            """)
        #expect(modules["Inherits"]?.output == "Global.swift")
        #expect(modules["Own"]?.output == "Own.swift")
    }

    @Test
    func overriddenOutputWinsOverModuleOutput() throws {
        let modules = try parse("""
            [modules.Own]
            output = "Own.swift"

            [modules.None]
            sources = []
            """, overriddenOutput: "/derived/Mocks.swift")
        #expect(modules["Own"]?.output == "/derived/Mocks.swift")
        #expect(modules["None"]?.output == "/derived/Mocks.swift")
    }

    @Test
    func overriddenOutputWinsOverGlobalOutput() throws {
        let modules = try parse("""
            output = "Global.swift"

            [modules.App]
            sources = []
            """, overriddenOutput: "/derived/Mocks.swift")
        #expect(modules["App"]?.output == "/derived/Mocks.swift")
    }

    @Test
    func missingOutputIsRejected() {
        #expect(throws: (any Error).self) {
            try parse("""
                [modules.App]
                sources = []
                """)
        }
    }

    // MARK: Modules

    @Test
    func multipleModules() throws {
        let modules = try parse("""
            output = "Mocks.swift"
            [modules.A]
            [modules.B]
            [modules.C]
            """)
        #expect(modules.keys.sorted() == ["A", "B", "C"])
    }

    @Test
    func requestedModuleNameFilters() throws {
        let contents = """
            output = "Mocks.swift"
            [modules.A]
            [modules.B]
            """
        #expect(try parse(contents, requestedModuleName: "B").keys.sorted() == ["B"])
        #expect(try parse(contents, requestedModuleName: "Missing").isEmpty)
    }

    @Test
    func noModules() throws {
        #expect(try parse("output = \"Mocks.swift\"").isEmpty)
        #expect(try parse("").isEmpty)
    }

    // MARK: Rejected configurations

    @Test(arguments: [
        // `modules` isn't a table.
        "modules = \"App\"",
        // A module isn't a table.
        "[modules]\nApp = \"Mocks.swift\"",
        // A value of the wrong type.
        "[modules.App]\noutput = \"Mocks.swift\"\n[modules.App.options]\nglob = \"yes\"",
        "[modules.App]\noutput = \"Mocks.swift\"\nsources = \"Sources/*.swift\"",
        // A filename format without the `{}` placeholder.
        "[modules.App]\noutput = \"Mocks\"\nfilenameFormat = \"Mock\"",
        // A leftover `xcodeproj` table, even without a target.
        "[modules.App]\noutput = \"Mocks.swift\"\n[modules.App.xcodeproj]\npath = \".\"",
        // Not valid TOML.
        "[modules.App\noutput = \"Mocks.swift\"",
        "[modules.App]\noutput = ",
    ])
    func rejected(_ contents: String) {
        #expect(throws: (any Error).self) {
            try parse(contents)
        }
    }

    // MARK: Real configurations

    @Test
    func repositoryCuckoofile() throws {
        let url = Self.repositoryRoot.appending(path: "Cuckoofile.toml")
        // The plugins set every module's output.
        let modules = try parse(
            String(contentsOf: url, encoding: .utf8),
            configurationPath: Path(url.path(percentEncoded: false)),
            overriddenOutput: "/derived/GeneratedMocks.swift"
        )
        #expect(modules.keys.sorted() == ["CuckooPluginTestSources", "CuckooTestSources"])
        #expect(modules["CuckooPluginTestSources"]?.sources == nil)
        #expect(modules["CuckooTestSources"]?.testableImports == ["Cuckoo", "CuckooTestSources"])
        #expect(modules["CuckooTestSources"]?.exclude == ["ExcludedTestClass", "ExcludedProtocol"])
        #expect(modules["CuckooTestSources"]?.options.keepDocumentation == false)
        #expect(modules["CuckooTestSources"]?.swiftModules.values.sorted() == ["CuckooTestSources"])
    }

    /// Every TOML example in the documentation articles parses, except the Cuckoo 2 half of the migration
    /// example, which is rejected with the way to migrate. Examples without an output get the plugin's.
    @Test
    func documentationExamples() throws {
        func examples(in article: String) throws -> [String] {
            let text = try String(
                contentsOf: Self.repositoryRoot.appending(path: "Source/Cuckoo.docc/\(article).md"),
                encoding: .utf8
            )
            return text.split(separator: "```toml\n", omittingEmptySubsequences: false).dropFirst().map {
                String($0.split(separator: "```", omittingEmptySubsequences: false).first ?? "")
            }
        }

        let gettingStarted = try examples(in: "GettingStarted")
        try #require(gettingStarted.count == 1)
        let pluginListed = try #require(try Cuckoofile.modules(
            from: gettingStarted[0],
            configurationPath: Self.configurationPath,
            overriddenOutput: "/derived/Mocks.swift",
            requestedModuleName: nil,
            pluginSources: [
                Module.PluginSource(path: Path("/project/Sources/App/A.swift"), swiftModule: "App"),
                Module.PluginSource(path: Path("/project/Sources/Core/B.swift"), swiftModule: "Core"),
            ]
        ).first)
        #expect(pluginListed.name == "App")
        #expect(pluginListed.testableImports == ["App"])
        // The plugin lists every dependency's files; the module takes those of the target with its name.
        #expect(pluginListed.sources == [Path("/project/Sources/App/A.swift")])
        #expect(pluginListed.sourcesAreFromPlugin)

        let cuckoofile = try examples(in: "Cuckoofile")
        try #require(cuckoofile.count == 5)

        let full = try #require(try parse(cuckoofile[0])["App"])
        #expect(full.output == "Tests/Generated/GeneratedMocks.swift")
        #expect(full.imports == ["Foundation"])
        #expect(full.exclude == ["AppDelegate"])
        #expect(full.options.keepDocumentation == false)
        #expect(full.options.defaultIsolation == .globalActor("MainActor"))

        let globs = try #require(try parse(cuckoofile[1], overriddenOutput: "/derived/Mocks.swift")["App"])
        #expect(globs.sources?.map(\.rawValue) == ["/project/Sources/App/**/*.swift", "/project/Sources/Shared/{Clock,Store}.swift"])

        let byModule = try #require(try parse(cuckoofile[2], overriddenOutput: "/derived/Mocks.swift")["AppAndCore"])
        #expect(byModule.swiftModules.values.sorted() == ["App", "Core"])

        let cuckoo2 = try #require(throws: Cuckoofile.ParseError.self) {
            try parse(cuckoofile[3])
        }
        #expect(String(describing: cuckoo2).contains(#"sources = ["MyApp/**/*.swift"]"#))

        let cuckoo3 = try #require(try parse(cuckoofile[4])["MyApp"])
        #expect(cuckoo3.sources?.map(\.rawValue) == ["/project/MyApp/**/*.swift", "/project/Shared/**/*.swift"])
    }
}
