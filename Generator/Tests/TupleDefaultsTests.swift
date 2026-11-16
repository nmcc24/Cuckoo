import Testing
@testable import CuckooGenerator

/// The tuple a mock passes for an unstubbed call's default, without its labels, and none for any other type.
@Suite
struct TupleDefaultsTests {
    @Test(arguments: [
        ("(Int, String)", "(Int, String)"),
        ("(count: Int, name: String?)", "(Int, String?)"),
        ("(Int, (inout Int) -> Void)", "(Int, (inout Int) -> Void)"),
        ("(Int, @Sendable () -> Void)", "(Int, @Sendable () -> Void)"),
        ("(Int, (borrowing Int) -> Void)", "(Int, (borrowing Int) -> Void)"),
        ("(first: Int, (isolated any Actor) -> Void)", "(Int, (isolated any Actor) -> Void)"),
    ])
    func tupleTypesLoseTheirLabels(type: String, expected: String) {
        #expect(GeneratorHelper.unlabeledTupleType(type) == expected)
    }

    @Test(arguments: [
        "Int",
        "(Int)",
        "(Int, String)?",
        "(repeat each T)",
        "(Int, repeat each T)",
    ])
    func otherTypesGetNoTupleDefault(type: String) {
        #expect(GeneratorHelper.unlabeledTupleType(type) == nil)
    }
}
