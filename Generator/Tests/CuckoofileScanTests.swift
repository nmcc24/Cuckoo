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
            glob = true

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
}
