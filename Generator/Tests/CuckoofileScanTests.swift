import Testing
@testable import CuckooGenerator

/// The plugin's line-by-line reading of a Cuckoofile, which finds the entries without a TOML parser.
struct CuckoofileScanTests {
    @Test
    func modulesComeFromTablesDottedKeysAndInlineTables() {
        let names = cuckoofileModuleNames(in: """
            modules.Kit.imports = ["Foundation"]

            [modules.App]
            sources = ["App/*.swift"]

            [modules.App.options]
            keepDocumentation = true

            [modules]
            Tools = { sources = ["Tools/*.swift"] }

            [modules."Quoted.Name"]
            """)
        #expect(names == ["App", "Tools", "Kit", "Quoted.Name"])
    }

    @Test
    func commentsAndStringsDontHideOrAddEntries() {
        let names = cuckoofileModuleNames(in: #"""
            # [modules.Commented]
            [modules.A] # a comment
            header = """
            [modules.InsideString]
            """
            [modules.B]
            """#)
        #expect(names == ["A", "B"])
    }

    private static let delimiter = String(repeating: "\"", count: 3)
    static let closingLines: [(line: String, closes: Bool)] = [
        ("x \\\\" + delimiter, true),          // x \\"""
        ("x \\" + delimiter, false),             // x \"""
        ("x \\\"" + delimiter, true),           // x \""""
        ("x " + delimiter, true),                // x """
        ("x \"\"" + delimiter, true),            // x """""
        ("x \"\" y", false),
    ]

    /// A basic multi-line string closes at three quotes that aren't escaped: `\"""` is an escaped quote and two
    /// more, `\\"""` an escaped backslash and the delimiter, and `""""` a quote and the delimiter.
    @Test(arguments: closingLines)
    func multilineBasicStringCloses(line: String, closes: Bool) {
        #expect(closesMultilineString(Substring(line), delimiter: "\"") == closes)
    }

    @Test
    func multilineLiteralStringHasNoEscapes() {
        #expect(closesMultilineString(#"x \'''"#, delimiter: "'"))
    }

    @Test
    func entriesAfterAnEscapedClosingAreRead() {
        let names = cuckoofileModuleNames(in: #"""
            [modules.A]
            header = """
            x \\"""
            [modules.B]
            """#)
        #expect(names == ["A", "B"])
    }

    @Test
    func sourcesAreFoundInEachSpelling() {
        #expect(cuckoofileEntry(named: "App", listsSourcesIn: "[modules.App]\nsources = [\"a.swift\"]"))
        #expect(cuckoofileEntry(named: "App", listsSourcesIn: "[modules]\nApp = { sources = [\"a.swift\"] }"))
        #expect(cuckoofileEntry(named: "App", listsSourcesIn: "modules.App.sources = [\"a.swift\"]"))
        #expect(!cuckoofileEntry(named: "App", listsSourcesIn: "[modules.App]\nimports = [\"Foundation\"]"))
        #expect(!cuckoofileEntry(named: "App", listsSourcesIn: "[modules.Other]\nsources = [\"a.swift\"]"))
    }

    /// An entry that no target can generate, such as a misspelled module, is a warning naming it.
    @Test
    func entriesNoTargetUsesAreNamed() {
        #expect(unusedCuckoofileEntriesWarning(entries: ["App", "AppTests"], usableNames: ["App", "AppTests", "Kit"]) == nil)
        let warning = unusedCuckoofileEntriesWarning(entries: ["App", "Netwrk"], usableNames: ["App", "AppTests", "Network"])
        #expect(warning?.hasPrefix("The Cuckoofile's entry 'Netwrk' names no target") == true)
    }

    /// A module that the target using Cuckoo reaches only through another module gets no mocks, so its entry warns,
    /// even when it's a target of the same package; so does a target that doesn't depend on Cuckoo.
    @Test
    func onlyDirectDependenciesOfTargetsUsingCuckooAreUsable() {
        let names = usableEntryNames(of: [
            ScannedTarget(name: "Core", dependsOnCuckoo: false, dependencies: []),
            ScannedTarget(name: "Feature", dependsOnCuckoo: false, dependencies: ["Core"]),
            ScannedTarget(name: "FeatureTests", dependsOnCuckoo: true, dependencies: ["Feature", "Cuckoo"]),
            ScannedTarget(name: "Mocks", dependsOnCuckoo: true, dependencies: ["Cuckoo"]),
        ])
        #expect(names == ["Feature", "FeatureTests", "Mocks", "Cuckoo"])
        let warning = unusedCuckoofileEntriesWarning(entries: ["Feature", "Core", "FeatureTests"], usableNames: names)
        #expect(warning?.contains("'Core'") == true)
        #expect(warning?.contains("'Feature'") == false)
        #expect(warning?.contains("direct dependency of the test target") == true)
    }

    /// The test target's own entry without `sources` mocks only its package's targets: the other packages' modules
    /// it leaves out are named, unless they have entries of their own.
    @Test
    func selfEntryWithoutSourcesNamesTheModulesItLeavesOut() {
        let warning = selfEntryLeavesOutWarning(target: "AppTests", entries: ["AppTests", "Kit"], listsSources: false, leftOut: ["Kit", "Network"])
        #expect(warning?.contains("[modules.AppTests] lists no sources") == true)
        #expect(warning?.contains("'Network'") == true)
        #expect(warning?.contains("'Kit'") == false)
        #expect(warning?.contains("[modules.Network]") == true)
        #expect(selfEntryLeavesOutWarning(target: "AppTests", entries: ["AppTests"], listsSources: true, leftOut: ["Network"]) == nil)
        #expect(selfEntryLeavesOutWarning(target: "AppTests", entries: ["Network"], listsSources: false, leftOut: ["Network"]) == nil)
        #expect(selfEntryLeavesOutWarning(target: "AppTests", entries: ["AppTests"], listsSources: false, leftOut: []) == nil)
    }
}
