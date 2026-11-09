import SwiftParser
import SwiftSyntax
import Testing
@testable import CuckooGenerator

/// The default implementation casts a method's associated types when its parameters or return type use them,
/// wherever inside the type they appear.
@Suite
struct ComplexTypeTests {
    @Test(arguments: ["Output", "[Output]", "(Output, T)", "[String: Output]", "Result<Output, any Error>", "Self.Output", "Output?"])
    func findsTheTypeInside(_ type: String) {
        #expect(complexType(type).containsType(named: "Output"))
    }

    @Test(arguments: ["Wrapper.Output", "OutputValue", "[Input]", "(T, Input)"])
    func ignoresOtherTypes(_ type: String) {
        #expect(!complexType(type).containsType(named: "Output"))
    }

    @Test
    func replacesTheTypeInside() {
        let replaced = complexType("(Output, [Wrapper.Output], Self.Output)").replaceType(named: "Output", with: "G.Output")
        #expect(replaced?.description == "(G.Output, [Wrapper.Output], G.Output)")
        #expect(complexType("[Input]").replaceType(named: "Output", with: "G.Output") == nil)
    }

    /// A closure type keeps its typed throws and its variadic parameters.
    @Test(arguments: ["() throws(NetErr) -> Int", "() async throws(Network.Failure) -> Void", "(String...) -> Void", "(Int, String...) throws -> Bool"])
    func closureTypeRoundTrips(_ type: String) {
        var parser = Parser(type)
        #expect(ComplexType(syntax: TypeSyntax.parse(from: &parser)).description == type)
    }

    private func complexType(_ source: String) -> ComplexType {
        .type(source)
    }
}
