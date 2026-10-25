import Foundation
import Testing
#if canImport(CuckooGenerator)
@testable import CuckooGenerator
#endif

/// Pins how `Cuckoofile.toml` is read: every key, how outputs fall back and override each other, module
/// filtering, and which configurations are rejected.
@Suite
struct CuckoofileTests {
    private static let repositoryRoot = URL(fileURLWithPath: #filePath)
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
            """)["App"])

        #expect(module.imports == ["Foundation", "UIKit"])
        #expect(module.publicImports == ["Shared"])
        #expect(module.testableImports == ["App"])
        // Relative sources resolve against the Cuckoofile's folder; absolute ones are kept.
        #expect(module.sources?.map(\.rawValue) == ["/project/Sources/App/**/*.swift", "/absolute/File.swift"])
        #expect(module.exclude == ["Excluded", "AlsoExcluded"])
        #expect(module.regex == "^Service")
        #expect(module.output == "Tests/Mocks")
        #expect(module.filenameFormat == "{}Mock")
        #expect(module.options.glob == false)
        #expect(module.options.keepDocumentation == false)
        #expect(module.options.enableInheritance == false)
        #expect(module.options.protocolsOnly == true)
        #expect(module.options.omitHeaders == true)
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
        #expect(module.regex == nil)
        #expect(module.filenameFormat == nil)
        #expect(module.options.glob == true)
        #expect(module.options.keepDocumentation == true)
        #expect(module.options.enableInheritance == true)
        #expect(module.options.protocolsOnly == false)
        #expect(module.options.omitHeaders == false)
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
    func overriddenOutputWithGlobalOutputIsRejected() {
        #expect(throws: Cuckoofile.ParseError.self) {
            try parse("""
                output = "Global.swift"

                [modules.App]
                sources = []
                """, overriddenOutput: "/derived/Mocks.swift")
        }
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
        let url = Self.repositoryRoot.appendingPathComponent("Cuckoofile.toml")
        let modules = try parse(
            String(contentsOf: url, encoding: .utf8),
            configurationPath: Path(url.path)
        )
        #expect(modules.keys.sorted() == ["CuckooTestSources", "CuckooTestSourcesSwiftUI"])
        #expect(modules["CuckooTestSources"]?.output == "Tests/Swift/Generated/GeneratedMocks.swift")
        #expect(modules["CuckooTestSources"]?.testableImports == ["Cuckoo", "CuckooTestSources"])
        #expect(modules["CuckooTestSources"]?.exclude == ["ExcludedTestClass", "ExcludedProtocol"])
        #expect(modules["CuckooTestSources"]?.options.keepDocumentation == false)
        #expect(modules["CuckooTestSourcesSwiftUI"]?.output == "Tests/Swift/Generated/GeneratedMocks+SwiftUI.swift")
    }

    /// Every TOML example in the README parses, except the Cuckoo 2 half of the migration example, which
    /// is rejected with the way to migrate. The modular-plugin example has no output of its own, because
    /// the plugin provides one.
    @Test
    func readmeExamples() throws {
        let readme = try String(
            contentsOf: Self.repositoryRoot.appendingPathComponent("README.md"),
            encoding: .utf8
        )
        let examples = readme.components(separatedBy: "```toml\n").dropFirst().map {
            $0.components(separatedBy: "```").first ?? ""
        }
        try #require(examples.count == 4)

        let configuration = try parse(examples[0])
        #expect(configuration.keys.sorted() == ["AnotherProject", "MyProject"])
        #expect(configuration["MyProject"]?.output == "Tests/Swift/Generated/GeneratedMocks+MyProject.swift")
        #expect(configuration["AnotherProject"]?.output == "Tests/Swift/Generated/GeneratedMocks.swift")

        let modular = try parse(examples[1], overriddenOutput: "/derived/Mocks.swift")
        #expect(modular.keys.sorted() == ["AggregationTargetTests", "TargetATests"])
        #expect(modular["AggregationTargetTests"]?.imports == ["Foundation", "TargetA", "TargetB"])

        let cuckoo2 = try #require(throws: Cuckoofile.ParseError.self) {
            try parse(examples[2])
        }
        #expect(String(describing: cuckoo2).contains(#"sources = ["MyApp/**/*.swift"]"#))

        let cuckoo3 = try #require(try parse(examples[3])["MyApp"])
        #expect(cuckoo3.sources?.map(\.rawValue) == ["/project/MyApp/**/*.swift", "/project/Shared/**/*.swift"])
    }
}
