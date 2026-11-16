import Testing
import Cuckoo

struct TestStructs {
    struct N {
        let g: Int
    }
    struct E: Equatable {
        let g: Int
    }
    struct H: Hashable {
        let g: Int
    }
}

/// Both overloads of a matcher function, called with the same arguments: the `ParameterMatcher` one, which
/// non-`Sendable` elements and closures get, and the `SendableMatcher` one. The result matches as the first does,
/// and records an issue where the second disagrees, so one test line covers both implementations.
func bothOverloads<T>(
    _ parameterMatcher: ParameterMatcher<T>,
    _ sendableMatcher: SendableMatcher<T>,
    sourceLocation: Testing.SourceLocation = #_sourceLocation
) -> ParameterMatcher<T> {
    ParameterMatcher { input in
        let matches = parameterMatcher.matches(input)
        #expect(sendableMatcher.matches(input) == matches, "The overloads disagree", sourceLocation: sourceLocation)
        return matches
    }
}

struct ArrayMatcherTest {
    // MARK: - Contains ANY of the elements.
    @Test
    func testContainsAnyOf() {
        // Variadic parameters.
        #expect(!bothOverloads(containsAnyOf(values: TestStructs.N(g: 1), TestStructs.N(g: 3), where: { $0.g == $1.g }), containsAnyOf(values: TestStructs.N(g: 1), TestStructs.N(g: 3), where: { $0.g == $1.g })).matches([2].map(TestStructs.N.init)))
        #expect(bothOverloads(containsAnyOf(values: TestStructs.N(g: 1), TestStructs.N(g: 3), where: { $0.g == $1.g }), containsAnyOf(values: TestStructs.N(g: 1), TestStructs.N(g: 3), where: { $0.g == $1.g })).matches([1, 2, 3].map(TestStructs.N.init)))
        #expect(bothOverloads(containsAnyOf(values: TestStructs.N(g: 1), TestStructs.N(g: 3), where: { $0.g == $1.g }), containsAnyOf(values: TestStructs.N(g: 1), TestStructs.N(g: 3), where: { $0.g == $1.g })).matches([1, 2, 3, 4, 5].map(TestStructs.N.init)))
        #expect(!bothOverloads(containsAnyOf(values: TestStructs.N(g: 1), TestStructs.N(g: 3), where: { $0.g == $1.g }), containsAnyOf(values: TestStructs.N(g: 1), TestStructs.N(g: 3), where: { $0.g == $1.g })).matches([4, 5, 6, 0].map(TestStructs.N.init)))
        #expect(!bothOverloads(containsAnyOf(values: TestStructs.N(g: 1), TestStructs.N(g: 3), where: { $0.g == $1.g }), containsAnyOf(values: TestStructs.N(g: 1), TestStructs.N(g: 3), where: { $0.g == $1.g })).matches([].map(TestStructs.N.init)))

        // Passed by array.
        #expect(bothOverloads(containsAnyOf((1...3).map(TestStructs.N.init), where: { $0.g == $1.g }), containsAnyOf((1...3).map(TestStructs.N.init), where: { $0.g == $1.g })).matches([2].map(TestStructs.N.init)))
        #expect(bothOverloads(containsAnyOf((1...3).map(TestStructs.N.init), where: { $0.g == $1.g }), containsAnyOf((1...3).map(TestStructs.N.init), where: { $0.g == $1.g })).matches([1, 2, 3].map(TestStructs.N.init)))
        #expect(bothOverloads(containsAnyOf((1...3).map(TestStructs.N.init), where: { $0.g == $1.g }), containsAnyOf((1...3).map(TestStructs.N.init), where: { $0.g == $1.g })).matches([1, 2, 3, 4, 5].map(TestStructs.N.init)))
        #expect(!bothOverloads(containsAnyOf((1...3).map(TestStructs.N.init), where: { $0.g == $1.g }), containsAnyOf((1...3).map(TestStructs.N.init), where: { $0.g == $1.g })).matches([4, 5, 6, 0].map(TestStructs.N.init)))
        #expect(!bothOverloads(containsAnyOf((1...3).map(TestStructs.N.init), where: { $0.g == $1.g }), containsAnyOf((1...3).map(TestStructs.N.init), where: { $0.g == $1.g })).matches([].map(TestStructs.N.init)))
    }

    @Test
    func containsAnyOfEquatable() {
        #expect(!bothOverloads(containsAnyOf(values: TestStructs.E(g: 1), TestStructs.E(g: 3)), containsAnyOf(values: TestStructs.E(g: 1), TestStructs.E(g: 3))).matches([2].map(TestStructs.E.init)))
        #expect(bothOverloads(containsAnyOf(values: TestStructs.E(g: 1), TestStructs.E(g: 3)), containsAnyOf(values: TestStructs.E(g: 1), TestStructs.E(g: 3))).matches([1, 2, 3].map(TestStructs.E.init)))
        #expect(bothOverloads(containsAnyOf(values: TestStructs.E(g: 1), TestStructs.E(g: 3)), containsAnyOf(values: TestStructs.E(g: 1), TestStructs.E(g: 3))).matches([1, 2, 3, 4, 5].map(TestStructs.E.init)))
        #expect(!bothOverloads(containsAnyOf(values: TestStructs.E(g: 1), TestStructs.E(g: 3)), containsAnyOf(values: TestStructs.E(g: 1), TestStructs.E(g: 3))).matches([4, 5, 6, 0].map(TestStructs.E.init)))
        #expect(!bothOverloads(containsAnyOf(values: TestStructs.E(g: 1), TestStructs.E(g: 3)), containsAnyOf(values: TestStructs.E(g: 1), TestStructs.E(g: 3))).matches([].map(TestStructs.E.init)))

        #expect(bothOverloads(containsAnyOf((1...3).map(TestStructs.E.init)), containsAnyOf((1...3).map(TestStructs.E.init))).matches([2].map(TestStructs.E.init)))
        #expect(bothOverloads(containsAnyOf((1...3).map(TestStructs.E.init)), containsAnyOf((1...3).map(TestStructs.E.init))).matches([1, 2, 3].map(TestStructs.E.init)))
        #expect(bothOverloads(containsAnyOf((1...3).map(TestStructs.E.init)), containsAnyOf((1...3).map(TestStructs.E.init))).matches([1, 2, 3, 4, 5].map(TestStructs.E.init)))
        #expect(!bothOverloads(containsAnyOf((1...3).map(TestStructs.E.init)), containsAnyOf((1...3).map(TestStructs.E.init))).matches([4, 5, 6, 0].map(TestStructs.E.init)))
        #expect(!bothOverloads(containsAnyOf((1...3).map(TestStructs.E.init)), containsAnyOf((1...3).map(TestStructs.E.init))).matches([].map(TestStructs.E.init)))
    }

    @Test
    func containsAnyOfHashable() {
        #expect(!bothOverloads(containsAnyOf(values: TestStructs.H(g: 1), TestStructs.H(g: 3)), containsAnyOf(values: TestStructs.H(g: 1), TestStructs.H(g: 3))).matches([2].map(TestStructs.H.init)))
        #expect(bothOverloads(containsAnyOf(values: TestStructs.H(g: 1), TestStructs.H(g: 3)), containsAnyOf(values: TestStructs.H(g: 1), TestStructs.H(g: 3))).matches([1, 2, 3].map(TestStructs.H.init)))
        #expect(bothOverloads(containsAnyOf(values: TestStructs.H(g: 1), TestStructs.H(g: 3)), containsAnyOf(values: TestStructs.H(g: 1), TestStructs.H(g: 3))).matches([1, 2, 3, 4, 5].map(TestStructs.H.init)))
        #expect(!bothOverloads(containsAnyOf(values: TestStructs.H(g: 1), TestStructs.H(g: 3)), containsAnyOf(values: TestStructs.H(g: 1), TestStructs.H(g: 3))).matches([4, 5, 6, 0].map(TestStructs.H.init)))
        #expect(!bothOverloads(containsAnyOf(values: TestStructs.H(g: 1), TestStructs.H(g: 3)), containsAnyOf(values: TestStructs.H(g: 1), TestStructs.H(g: 3))).matches([].map(TestStructs.H.init)))

        #expect(bothOverloads(containsAnyOf((1...3).map(TestStructs.H.init)), containsAnyOf((1...3).map(TestStructs.H.init))).matches([2].map(TestStructs.H.init)))
        #expect(bothOverloads(containsAnyOf((1...3).map(TestStructs.H.init)), containsAnyOf((1...3).map(TestStructs.H.init))).matches([1, 2, 3].map(TestStructs.H.init)))
        #expect(bothOverloads(containsAnyOf((1...3).map(TestStructs.H.init)), containsAnyOf((1...3).map(TestStructs.H.init))).matches([1, 2, 3, 4, 5].map(TestStructs.H.init)))
        #expect(!bothOverloads(containsAnyOf((1...3).map(TestStructs.H.init)), containsAnyOf((1...3).map(TestStructs.H.init))).matches([4, 5, 6, 0].map(TestStructs.H.init)))
        #expect(!bothOverloads(containsAnyOf((1...3).map(TestStructs.H.init)), containsAnyOf((1...3).map(TestStructs.H.init))).matches([].map(TestStructs.H.init)))
    }

    // MARK: - Contains ALL of the elements.
    @Test
    func testContainsAllOf() {
        #expect(!bothOverloads(containsAllOf(values: TestStructs.N(g: 1), TestStructs.N(g: 3), where: { $0.g == $1.g }), containsAllOf(values: TestStructs.N(g: 1), TestStructs.N(g: 3), where: { $0.g == $1.g })).matches([2].map(TestStructs.N.init)))
        #expect(bothOverloads(containsAllOf(values: TestStructs.N(g: 1), TestStructs.N(g: 3), where: { $0.g == $1.g }), containsAllOf(values: TestStructs.N(g: 1), TestStructs.N(g: 3), where: { $0.g == $1.g })).matches([1, 2, 3].map(TestStructs.N.init)))
        #expect(bothOverloads(containsAllOf(values: TestStructs.N(g: 1), TestStructs.N(g: 3), where: { $0.g == $1.g }), containsAllOf(values: TestStructs.N(g: 1), TestStructs.N(g: 3), where: { $0.g == $1.g })).matches([1, 2, 3, 4, 5].map(TestStructs.N.init)))
        #expect(!bothOverloads(containsAllOf(values: TestStructs.N(g: 1), TestStructs.N(g: 3), where: { $0.g == $1.g }), containsAllOf(values: TestStructs.N(g: 1), TestStructs.N(g: 3), where: { $0.g == $1.g })).matches([4, 5, 6, 0].map(TestStructs.N.init)))
        #expect(!bothOverloads(containsAllOf(values: TestStructs.N(g: 1), TestStructs.N(g: 3), where: { $0.g == $1.g }), containsAllOf(values: TestStructs.N(g: 1), TestStructs.N(g: 3), where: { $0.g == $1.g })).matches([3].map(TestStructs.N.init)))

        #expect(!bothOverloads(containsAllOf((1...3).map(TestStructs.N.init), where: { $0.g == $1.g }), containsAllOf((1...3).map(TestStructs.N.init), where: { $0.g == $1.g })).matches([2].map(TestStructs.N.init)))
        #expect(bothOverloads(containsAllOf((1...3).map(TestStructs.N.init), where: { $0.g == $1.g }), containsAllOf((1...3).map(TestStructs.N.init), where: { $0.g == $1.g })).matches([1, 2, 3].map(TestStructs.N.init)))
        #expect(bothOverloads(containsAllOf((1...3).map(TestStructs.N.init), where: { $0.g == $1.g }), containsAllOf((1...3).map(TestStructs.N.init), where: { $0.g == $1.g })).matches([1, 2, 3, 4, 5].map(TestStructs.N.init)))
        #expect(!bothOverloads(containsAllOf((1...3).map(TestStructs.N.init), where: { $0.g == $1.g }), containsAllOf((1...3).map(TestStructs.N.init), where: { $0.g == $1.g })).matches([4, 5, 6, 0].map(TestStructs.N.init)))
        #expect(!bothOverloads(containsAllOf((1...3).map(TestStructs.N.init), where: { $0.g == $1.g }), containsAllOf((1...3).map(TestStructs.N.init), where: { $0.g == $1.g })).matches([3].map(TestStructs.N.init)))
    }

    @Test
    func containsAllOfEquatable() {
        #expect(!bothOverloads(containsAllOf(values: TestStructs.E(g: 1), TestStructs.E(g: 3)), containsAllOf(values: TestStructs.E(g: 1), TestStructs.E(g: 3))).matches([2].map(TestStructs.E.init)))
        #expect(bothOverloads(containsAllOf(values: TestStructs.E(g: 1), TestStructs.E(g: 3)), containsAllOf(values: TestStructs.E(g: 1), TestStructs.E(g: 3))).matches([1, 2, 3].map(TestStructs.E.init)))
        #expect(bothOverloads(containsAllOf(values: TestStructs.E(g: 1), TestStructs.E(g: 3)), containsAllOf(values: TestStructs.E(g: 1), TestStructs.E(g: 3))).matches([1, 2, 3, 4, 5].map(TestStructs.E.init)))
        #expect(!bothOverloads(containsAllOf(values: TestStructs.E(g: 1), TestStructs.E(g: 3)), containsAllOf(values: TestStructs.E(g: 1), TestStructs.E(g: 3))).matches([4, 5, 6, 0].map(TestStructs.E.init)))
        #expect(!bothOverloads(containsAllOf(values: TestStructs.E(g: 1), TestStructs.E(g: 3)), containsAllOf(values: TestStructs.E(g: 1), TestStructs.E(g: 3))).matches([3].map(TestStructs.E.init)))

        #expect(!bothOverloads(containsAllOf((1...3).map(TestStructs.E.init)), containsAllOf((1...3).map(TestStructs.E.init))).matches([2].map(TestStructs.E.init)))
        #expect(bothOverloads(containsAllOf((1...3).map(TestStructs.E.init)), containsAllOf((1...3).map(TestStructs.E.init))).matches([1, 2, 3].map(TestStructs.E.init)))
        #expect(bothOverloads(containsAllOf((1...3).map(TestStructs.E.init)), containsAllOf((1...3).map(TestStructs.E.init))).matches([1, 2, 3, 4, 5].map(TestStructs.E.init)))
        #expect(!bothOverloads(containsAllOf((1...3).map(TestStructs.E.init)), containsAllOf((1...3).map(TestStructs.E.init))).matches([4, 5, 6, 0].map(TestStructs.E.init)))
        #expect(!bothOverloads(containsAllOf((1...3).map(TestStructs.E.init)), containsAllOf((1...3).map(TestStructs.E.init))).matches([3].map(TestStructs.E.init)))
    }

    @Test
    func containsAllOfHashable() {
        #expect(!bothOverloads(containsAllOf(values: TestStructs.H(g: 1), TestStructs.H(g: 3)), containsAllOf(values: TestStructs.H(g: 1), TestStructs.H(g: 3))).matches([2].map(TestStructs.H.init)))
        #expect(bothOverloads(containsAllOf(values: TestStructs.H(g: 1), TestStructs.H(g: 3)), containsAllOf(values: TestStructs.H(g: 1), TestStructs.H(g: 3))).matches([1, 2, 3].map(TestStructs.H.init)))
        #expect(bothOverloads(containsAllOf(values: TestStructs.H(g: 1), TestStructs.H(g: 3)), containsAllOf(values: TestStructs.H(g: 1), TestStructs.H(g: 3))).matches([1, 2, 3, 4, 5].map(TestStructs.H.init)))
        #expect(!bothOverloads(containsAllOf(values: TestStructs.H(g: 1), TestStructs.H(g: 3)), containsAllOf(values: TestStructs.H(g: 1), TestStructs.H(g: 3))).matches([4, 5, 6, 0].map(TestStructs.H.init)))
        #expect(!bothOverloads(containsAllOf(values: TestStructs.H(g: 1), TestStructs.H(g: 3)), containsAllOf(values: TestStructs.H(g: 1), TestStructs.H(g: 3))).matches([3].map(TestStructs.H.init)))

        #expect(!bothOverloads(containsAllOf((1...3).map(TestStructs.H.init)), containsAllOf((1...3).map(TestStructs.H.init))).matches([2].map(TestStructs.H.init)))
        #expect(bothOverloads(containsAllOf((1...3).map(TestStructs.H.init)), containsAllOf((1...3).map(TestStructs.H.init))).matches([1, 2, 3].map(TestStructs.H.init)))
        #expect(bothOverloads(containsAllOf((1...3).map(TestStructs.H.init)), containsAllOf((1...3).map(TestStructs.H.init))).matches([1, 2, 3, 4, 5].map(TestStructs.H.init)))
        #expect(!bothOverloads(containsAllOf((1...3).map(TestStructs.H.init)), containsAllOf((1...3).map(TestStructs.H.init))).matches([4, 5, 6, 0].map(TestStructs.H.init)))
        #expect(!bothOverloads(containsAllOf((1...3).map(TestStructs.H.init)), containsAllOf((1...3).map(TestStructs.H.init))).matches([3].map(TestStructs.H.init)))
    }

    @Test
    func containsAllOfMultiple() {
        #expect(!bothOverloads(containsAllOf(values: 1, 3, 2, 2, 1), containsAllOf(values: 1, 3, 2, 2, 1)).matches([2]))
        #expect(!bothOverloads(containsAllOf(values: 1, 3, 2, 2, 1), containsAllOf(values: 1, 3, 2, 2, 1)).matches([1, 2, 3]))
        #expect(!bothOverloads(containsAllOf(values: 1, 3, 2, 2, 1), containsAllOf(values: 1, 3, 2, 2, 1)).matches([1, 3, 2, 2]))
        #expect(bothOverloads(containsAllOf(values: 1, 3, 2, 2, 1), containsAllOf(values: 1, 3, 2, 2, 1)).matches([1, 3, 2, 2, 1]))

        #expect(!bothOverloads(containsAllOf([1, 3, 2, 2, 1]), containsAllOf([1, 3, 2, 2, 1])).matches([2]))
        #expect(!bothOverloads(containsAllOf([1, 3, 2, 2, 1]), containsAllOf([1, 3, 2, 2, 1])).matches([1, 2, 3]))
        #expect(!bothOverloads(containsAllOf([1, 3, 2, 2, 1]), containsAllOf([1, 3, 2, 2, 1])).matches([1, 3, 2, 2]))
        #expect(bothOverloads(containsAllOf([1, 3, 2, 2, 1]), containsAllOf([1, 3, 2, 2, 1])).matches([1, 3, 2, 2, 1]))
    }

    /// The matched sequence may hold an element more often than the matcher asks for it, as with the `Equatable`
    /// overload.
    @Test
    func containsAllOfAllowsExtraCopies() {
        #expect(bothOverloads(containsAllOf(values: 1, 2), containsAllOf(values: 1, 2)).matches([1, 1, 2]))
        #expect(bothOverloads(containsAllOf([1, 2]), containsAllOf([1, 2])).matches([2, 1, 2, 1]))
        #expect(bothOverloads(containsAllOf(values: TestStructs.H(g: 1)), containsAllOf(values: TestStructs.H(g: 1))).matches([1, 1].map(TestStructs.H.init)))
        #expect(bothOverloads(containsAllOf(values: TestStructs.E(g: 1)), containsAllOf(values: TestStructs.E(g: 1))).matches([1, 1].map(TestStructs.E.init)))
        #expect(!bothOverloads(containsAllOf(values: 1, 1, 2), containsAllOf(values: 1, 1, 2)).matches([1, 2]))
    }

    // MARK: - Contains NONE of the elements.
    @Test
    func testContainsNoneOf() {
        // Variadic parameters.
        #expect(bothOverloads(containsNoneOf(values: TestStructs.N(g: 1), TestStructs.N(g: 3), where: { $0.g == $1.g }), containsNoneOf(values: TestStructs.N(g: 1), TestStructs.N(g: 3), where: { $0.g == $1.g })).matches([2].map(TestStructs.N.init)))
        #expect(!bothOverloads(containsNoneOf(values: TestStructs.N(g: 1), TestStructs.N(g: 3), where: { $0.g == $1.g }), containsNoneOf(values: TestStructs.N(g: 1), TestStructs.N(g: 3), where: { $0.g == $1.g })).matches([1, 2, 3].map(TestStructs.N.init)))
        #expect(!bothOverloads(containsNoneOf(values: TestStructs.N(g: 1), TestStructs.N(g: 3), where: { $0.g == $1.g }), containsNoneOf(values: TestStructs.N(g: 1), TestStructs.N(g: 3), where: { $0.g == $1.g })).matches([1, 2, 3, 4, 5].map(TestStructs.N.init)))
        #expect(bothOverloads(containsNoneOf(values: TestStructs.N(g: 1), TestStructs.N(g: 3), where: { $0.g == $1.g }), containsNoneOf(values: TestStructs.N(g: 1), TestStructs.N(g: 3), where: { $0.g == $1.g })).matches([4, 5, 6, 0].map(TestStructs.N.init)))
        #expect(bothOverloads(containsNoneOf(values: TestStructs.N(g: 1), TestStructs.N(g: 3), where: { $0.g == $1.g }), containsNoneOf(values: TestStructs.N(g: 1), TestStructs.N(g: 3), where: { $0.g == $1.g })).matches([].map(TestStructs.N.init)))

        // Passed by array.
        #expect(!bothOverloads(containsNoneOf((1...3).map(TestStructs.N.init), where: { $0.g == $1.g }), containsNoneOf((1...3).map(TestStructs.N.init), where: { $0.g == $1.g })).matches([2].map(TestStructs.N.init)))
        #expect(!bothOverloads(containsNoneOf((1...3).map(TestStructs.N.init), where: { $0.g == $1.g }), containsNoneOf((1...3).map(TestStructs.N.init), where: { $0.g == $1.g })).matches([1, 2, 3].map(TestStructs.N.init)))
        #expect(!bothOverloads(containsNoneOf((1...3).map(TestStructs.N.init), where: { $0.g == $1.g }), containsNoneOf((1...3).map(TestStructs.N.init), where: { $0.g == $1.g })).matches([1, 2, 3, 4, 5].map(TestStructs.N.init)))
        #expect(bothOverloads(containsNoneOf((1...3).map(TestStructs.N.init), where: { $0.g == $1.g }), containsNoneOf((1...3).map(TestStructs.N.init), where: { $0.g == $1.g })).matches([4, 5, 6, 0].map(TestStructs.N.init)))
        #expect(bothOverloads(containsNoneOf((1...3).map(TestStructs.N.init), where: { $0.g == $1.g }), containsNoneOf((1...3).map(TestStructs.N.init), where: { $0.g == $1.g })).matches([].map(TestStructs.N.init)))
    }

    @Test
    func containsNoneOfEquatable() {
        #expect(bothOverloads(containsNoneOf(values: TestStructs.E(g: 1), TestStructs.E(g: 3)), containsNoneOf(values: TestStructs.E(g: 1), TestStructs.E(g: 3))).matches([2].map(TestStructs.E.init)))
        #expect(!bothOverloads(containsNoneOf(values: TestStructs.E(g: 1), TestStructs.E(g: 3)), containsNoneOf(values: TestStructs.E(g: 1), TestStructs.E(g: 3))).matches([1, 2, 3].map(TestStructs.E.init)))
        #expect(!bothOverloads(containsNoneOf(values: TestStructs.E(g: 1), TestStructs.E(g: 3)), containsNoneOf(values: TestStructs.E(g: 1), TestStructs.E(g: 3))).matches([1, 2, 3, 4, 5].map(TestStructs.E.init)))
        #expect(bothOverloads(containsNoneOf(values: TestStructs.E(g: 1), TestStructs.E(g: 3)), containsNoneOf(values: TestStructs.E(g: 1), TestStructs.E(g: 3))).matches([4, 5, 6, 0].map(TestStructs.E.init)))
        #expect(bothOverloads(containsNoneOf(values: TestStructs.E(g: 1), TestStructs.E(g: 3)), containsNoneOf(values: TestStructs.E(g: 1), TestStructs.E(g: 3))).matches([].map(TestStructs.E.init)))

        #expect(!bothOverloads(containsNoneOf((1...3).map(TestStructs.E.init)), containsNoneOf((1...3).map(TestStructs.E.init))).matches([2].map(TestStructs.E.init)))
        #expect(!bothOverloads(containsNoneOf((1...3).map(TestStructs.E.init)), containsNoneOf((1...3).map(TestStructs.E.init))).matches([1, 2, 3].map(TestStructs.E.init)))
        #expect(!bothOverloads(containsNoneOf((1...3).map(TestStructs.E.init)), containsNoneOf((1...3).map(TestStructs.E.init))).matches([1, 2, 3, 4, 5].map(TestStructs.E.init)))
        #expect(bothOverloads(containsNoneOf((1...3).map(TestStructs.E.init)), containsNoneOf((1...3).map(TestStructs.E.init))).matches([4, 5, 6, 0].map(TestStructs.E.init)))
        #expect(bothOverloads(containsNoneOf((1...3).map(TestStructs.E.init)), containsNoneOf((1...3).map(TestStructs.E.init))).matches([].map(TestStructs.E.init)))
    }

    @Test
    func containsNoneOfHashable() {
        #expect(bothOverloads(containsNoneOf(values: TestStructs.H(g: 1), TestStructs.H(g: 3)), containsNoneOf(values: TestStructs.H(g: 1), TestStructs.H(g: 3))).matches([2].map(TestStructs.H.init)))
        #expect(!bothOverloads(containsNoneOf(values: TestStructs.H(g: 1), TestStructs.H(g: 3)), containsNoneOf(values: TestStructs.H(g: 1), TestStructs.H(g: 3))).matches([1, 2, 3].map(TestStructs.H.init)))
        #expect(!bothOverloads(containsNoneOf(values: TestStructs.H(g: 1), TestStructs.H(g: 3)), containsNoneOf(values: TestStructs.H(g: 1), TestStructs.H(g: 3))).matches([1, 2, 3, 4, 5].map(TestStructs.H.init)))
        #expect(bothOverloads(containsNoneOf(values: TestStructs.H(g: 1), TestStructs.H(g: 3)), containsNoneOf(values: TestStructs.H(g: 1), TestStructs.H(g: 3))).matches([4, 5, 6, 0].map(TestStructs.H.init)))
        #expect(bothOverloads(containsNoneOf(values: TestStructs.H(g: 1), TestStructs.H(g: 3)), containsNoneOf(values: TestStructs.H(g: 1), TestStructs.H(g: 3))).matches([].map(TestStructs.H.init)))

        #expect(!bothOverloads(containsNoneOf((1...3).map(TestStructs.H.init)), containsNoneOf((1...3).map(TestStructs.H.init))).matches([2].map(TestStructs.H.init)))
        #expect(!bothOverloads(containsNoneOf((1...3).map(TestStructs.H.init)), containsNoneOf((1...3).map(TestStructs.H.init))).matches([1, 2, 3].map(TestStructs.H.init)))
        #expect(!bothOverloads(containsNoneOf((1...3).map(TestStructs.H.init)), containsNoneOf((1...3).map(TestStructs.H.init))).matches([1, 2, 3, 4, 5].map(TestStructs.H.init)))
        #expect(bothOverloads(containsNoneOf((1...3).map(TestStructs.H.init)), containsNoneOf((1...3).map(TestStructs.H.init))).matches([4, 5, 6, 0].map(TestStructs.H.init)))
        #expect(bothOverloads(containsNoneOf((1...3).map(TestStructs.H.init)), containsNoneOf((1...3).map(TestStructs.H.init))).matches([].map(TestStructs.H.init)))
    }

    // MARK: - Has length N (exact, at least, at most).
    @Test
    func hasLengthExact() {
        #expect(hasLength(exactly: 4).matches([1, 2, 3, 4]))
        #expect(!hasLength(exactly: 2).matches([1, 2, 3, 4]))
        #expect(hasLength(exactly: 0).matches([]))
    }

    @Test
    func hasLengthAtLeast() {
        #expect(hasLength(atLeast: 4).matches([1, 2, 3, 4]))
        #expect(hasLength(atLeast: 2).matches([1, 2, 3, 4]))
        #expect(hasLength(atLeast: 0).matches([]))

        #expect(!hasLength(atLeast: 4, inclusive: false).matches([1, 2, 3, 4]))
        #expect(hasLength(atLeast: 2, inclusive: false).matches([1, 2, 3, 4]))
        #expect(!hasLength(atLeast: 0, inclusive: false).matches([]))
    }

    @Test
    func hasLengthAtMost() {
        #expect(hasLength(atMost: 4).matches([1, 2, 3, 4]))
        #expect(!hasLength(atMost: 2).matches([1, 2, 3, 4]))
        #expect(hasLength(atMost: 0).matches([]))

        #expect(hasLength(atMost: 5, inclusive: false).matches([1, 2, 3, 4]))
        #expect(!hasLength(atMost: 2, inclusive: false).matches([1, 2, 3, 4]))
        #expect(!hasLength(atMost: 0, inclusive: false).matches([]))
    }

    @Test
    func hasLengthIn() {
        #expect(!hasLength(in: 1..<3).matches([Int]()))
        #expect(hasLength(in: 1..<3).matches([1]))
        #expect(hasLength(in: 1..<3).matches([1, 2]))
        #expect(!hasLength(in: 1..<3).matches([1, 2, 3]))

        #expect(hasLength(in: 1...3).matches([1, 2, 3]))
        #expect(!hasLength(in: 1...3).matches([1, 2, 3, 4]))
        #expect(hasLength(in: 2...).matches([1, 2, 3, 4]))
        #expect(!hasLength(in: 2...).matches([1]))
        #expect(hasLength(in: ..<2).matches([Int]()))
    }
}
