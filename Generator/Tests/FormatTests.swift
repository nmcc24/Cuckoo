import Testing
@testable import CuckooGenerator

/// The generator lays its output out with swift-syntax's formatter, with at most one blank line in a row, and refuses
/// output that doesn't parse.
@Suite
struct FormatTests {
    @Test
    func formatsValidSource() throws {
        let formatted = try GeneratorHelper.format("struct A {\nfunc f() -> Int { 1 }\n}\n")
        #expect(formatted == "struct A {\n    func f() -> Int {\n        1\n    }\n}\n")
    }

    @Test
    func refusesSourceThatDoesNotParse() {
        let source = "struct A {\n    func f(\n}\n"
        #expect {
            try GeneratorHelper.format(source)
        } throws: { error in
            let description = String(describing: error)
            return description.contains("don't parse, at line") && description.contains("Cuckoo bug")
        }
    }

    @Test
    func keepsOneBlankLine() throws {
        let formatted = try GeneratorHelper.format("struct A {\n    var a = 1\n\n    \n\n    var b = 2\n}\n")
        #expect(formatted == "struct A {\n    var a = 1\n\n    var b = 2\n}\n")
    }

    @Test
    func dropsBlankLinesInsideBraces() throws {
        let formatted = try GeneratorHelper.format("struct A {\n\n    var a = 1\n\n}\n\nstruct B {\n\n}\n")
        #expect(formatted == "struct A {\n    var a = 1\n}\n\nstruct B {\n}\n")
    }

    @Test
    func leavesStringLiteralsAlone() throws {
        let source = "let s = \"\"\"\n    a\n\n\n    b\n    \"\"\"\n"
        #expect(try GeneratorHelper.format(source) == source)
    }

    @Test
    func joinsPartsWithOneBlankLine() {
        #expect(["import A\n", "\n", "struct B {}\n\n"].joinedByBlankLines() == "import A\n\nstruct B {}\n")
    }
}
