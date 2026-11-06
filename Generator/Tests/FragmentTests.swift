import SwiftParser
import SwiftSyntax
import Testing
@testable import CuckooGenerator

/// Generated code is parsed piece by piece, so a piece that doesn't parse names the declaration it was generated for.
@Suite
struct FragmentTests {
    @Test
    func parsesOneMember() throws {
        let member = try Fragment.member("#if DEBUG\nfunc f() {}\n#endif", of: "A.f")
        #expect(String(describing: member).contains("#if DEBUG\nfunc f() {}\n#endif"))
    }

    @Test
    func namesTheDeclarationOfAMemberThatDoesNotParse() {
        #expect {
            try Fragment.member("func f( {}", of: "Service.load")
        } throws: { error in
            String(describing: error).contains("`Service.load` doesn't parse")
        }
    }

    @Test
    func refusesMoreThanOneMember() {
        #expect(throws: FragmentError.self) {
            try Fragment.member("func f() {}\nfunc g() {}", of: "A.f")
        }
    }

    @Test
    func namesTheDeclarationOfATypeThatDoesNotParse() {
        #expect {
            try Fragment.declaration("final class AStub: {\n}", of: "AStub")
        } throws: { error in
            String(describing: error).contains("`AStub` doesn't parse")
        }
    }

    @Test
    func quotesALiteral() {
        #expect(Fragment.literal("load(_ p0: String) -> Int") == #""load(_ p0: String) -> Int""#)
    }

    @Test(arguments: [
        #"say(_ p0: String = "hi")"#,
        #"path\(to)\n"#,
        "line\nbreak\r\ttab\0nul\u{7}bell",
        "`raw identifier` ü 🐦",
    ])
    func escapesALiteralThatParsesBackToTheSameString(_ value: String) throws {
        let source = "let s = \(Fragment.literal(value))"
        let tree = Parser.parse(source: source)
        #expect(!tree.hasError)
        let literal = try #require(tree.statements.first?.item.as(VariableDeclSyntax.self)?.bindings.first?.initializer?.value.as(StringLiteralExprSyntax.self))
        #expect(literal.representedLiteralValue == value)
    }
}
