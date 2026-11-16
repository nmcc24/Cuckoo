import Testing
@testable import CuckooGenerator

/// The tuple a mock passes for an unstubbed call's default: unlabeled, and left out where `(...).self` can't spell it.
@Suite
struct TupleDefaultsTests {
    @Test(arguments: [
        ("(Int, String)", "(Int, String)"),
        ("(count: Int, name: String?)", "(Int, String?)"),
        ("(Int, (inout Int) -> Void)", "(Int, (inout Int) -> Void)"),
        ("(Int, @Sendable () -> Void)", "(Int, @Sendable () -> Void)"),
    ])
    func tupleTypesLoseTheirLabels(type: String, expected: String) {
        #expect(GeneratorHelper.unlabeledTupleType(type) == expected)
    }

    @Test(arguments: [
        "Int",
        "(Int)",
        "(Int, String)?",
        "(repeat each T)",
        "(Int, (borrowing Int) -> Void)",
        "(Int, (consuming String) -> Void)",
        "(Int, (isolated any Actor) -> Void)",
    ])
    func otherTypesGetNoTupleDefault(type: String) {
        #expect(GeneratorHelper.unlabeledTupleType(type) == nil)
    }
}
