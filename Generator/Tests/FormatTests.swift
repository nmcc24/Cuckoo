import Testing
@testable import CuckooGenerator

/// The generator lays its output out with swift-syntax's formatter, and refuses output that doesn't parse.
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
}
