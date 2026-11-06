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
}
