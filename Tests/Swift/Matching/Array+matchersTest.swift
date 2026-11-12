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

struct ArrayMatcherTest {
    // MARK: - Contains ANY of the elements.
    @Test
    func testContainsAnyOf() {
        // Variadic parameters.
        #expect(!containsAnyOf(values: .init(g: 1), .init(g: 3), where: { $0.g == $1.g }).matches([2].map(TestStructs.N.init)))
        #expect(containsAnyOf(values: .init(g: 1), .init(g: 3), where: { $0.g == $1.g }).matches([1, 2, 3].map(TestStructs.N.init)))
        #expect(containsAnyOf(values: .init(g: 1), .init(g: 3), where: { $0.g == $1.g }).matches([1, 2, 3, 4, 5].map(TestStructs.N.init)))
        #expect(!containsAnyOf(values: .init(g: 1), .init(g: 3), where: { $0.g == $1.g }).matches([4, 5, 6, 0].map(TestStructs.N.init)))
        #expect(!containsAnyOf(values: .init(g: 1), .init(g: 3), where: { $0.g == $1.g }).matches([].map(TestStructs.N.init)))

        // Passed by array.
        #expect(containsAnyOf((1...3).map(TestStructs.N.init), where: { $0.g == $1.g }).matches([2].map(TestStructs.N.init)))
        #expect(containsAnyOf((1...3).map(TestStructs.N.init), where: { $0.g == $1.g }).matches([1, 2, 3].map(TestStructs.N.init)))
        #expect(containsAnyOf((1...3).map(TestStructs.N.init), where: { $0.g == $1.g }).matches([1, 2, 3, 4, 5].map(TestStructs.N.init)))
        #expect(!containsAnyOf((1...3).map(TestStructs.N.init), where: { $0.g == $1.g }).matches([4, 5, 6, 0].map(TestStructs.N.init)))
        #expect(!containsAnyOf((1...3).map(TestStructs.N.init), where: { $0.g == $1.g }).matches([].map(TestStructs.N.init)))
    }

    @Test
    func containsAnyOfEquatable() {
        #expect(!containsAnyOf(values: .init(g: 1), .init(g: 3)).matches([2].map(TestStructs.E.init)))
        #expect(containsAnyOf(values: .init(g: 1), .init(g: 3)).matches([1, 2, 3].map(TestStructs.E.init)))
        #expect(containsAnyOf(values: .init(g: 1), .init(g: 3)).matches([1, 2, 3, 4, 5].map(TestStructs.E.init)))
        #expect(!containsAnyOf(values: .init(g: 1), .init(g: 3)).matches([4, 5, 6, 0].map(TestStructs.E.init)))
        #expect(!containsAnyOf(values: .init(g: 1), .init(g: 3)).matches([].map(TestStructs.E.init)))

        #expect(containsAnyOf((1...3).map(TestStructs.E.init)).matches([2].map(TestStructs.E.init)))
        #expect(containsAnyOf((1...3).map(TestStructs.E.init)).matches([1, 2, 3].map(TestStructs.E.init)))
        #expect(containsAnyOf((1...3).map(TestStructs.E.init)).matches([1, 2, 3, 4, 5].map(TestStructs.E.init)))
        #expect(!containsAnyOf((1...3).map(TestStructs.E.init)).matches([4, 5, 6, 0].map(TestStructs.E.init)))
        #expect(!containsAnyOf((1...3).map(TestStructs.E.init)).matches([].map(TestStructs.E.init)))
    }

    @Test
    func containsAnyOfHashable() {
        #expect(!containsAnyOf(values: .init(g: 1), .init(g: 3)).matches([2].map(TestStructs.H.init)))
        #expect(containsAnyOf(values: .init(g: 1), .init(g: 3)).matches([1, 2, 3].map(TestStructs.H.init)))
        #expect(containsAnyOf(values: .init(g: 1), .init(g: 3)).matches([1, 2, 3, 4, 5].map(TestStructs.H.init)))
        #expect(!containsAnyOf(values: .init(g: 1), .init(g: 3)).matches([4, 5, 6, 0].map(TestStructs.H.init)))
        #expect(!containsAnyOf(values: .init(g: 1), .init(g: 3)).matches([].map(TestStructs.H.init)))

        #expect(containsAnyOf((1...3).map(TestStructs.H.init)).matches([2].map(TestStructs.H.init)))
        #expect(containsAnyOf((1...3).map(TestStructs.H.init)).matches([1, 2, 3].map(TestStructs.H.init)))
        #expect(containsAnyOf((1...3).map(TestStructs.H.init)).matches([1, 2, 3, 4, 5].map(TestStructs.H.init)))
        #expect(!containsAnyOf((1...3).map(TestStructs.H.init)).matches([4, 5, 6, 0].map(TestStructs.H.init)))
        #expect(!containsAnyOf((1...3).map(TestStructs.H.init)).matches([].map(TestStructs.H.init)))
    }

    // MARK: - Contains ALL of the elements.
    @Test
    func testContainsAllOf() {
        #expect(!containsAllOf(values: .init(g: 1), .init(g: 3), where: { $0.g == $1.g }).matches([2].map(TestStructs.N.init)))
        #expect(containsAllOf(values: .init(g: 1), .init(g: 3), where: { $0.g == $1.g }).matches([1, 2, 3].map(TestStructs.N.init)))
        #expect(containsAllOf(values: .init(g: 1), .init(g: 3), where: { $0.g == $1.g }).matches([1, 2, 3, 4, 5].map(TestStructs.N.init)))
        #expect(!containsAllOf(values: .init(g: 1), .init(g: 3), where: { $0.g == $1.g }).matches([4, 5, 6, 0].map(TestStructs.N.init)))
        #expect(!containsAllOf(values: .init(g: 1), .init(g: 3), where: { $0.g == $1.g }).matches([3].map(TestStructs.N.init)))

        #expect(!containsAllOf((1...3).map(TestStructs.N.init), where: { $0.g == $1.g }).matches([2].map(TestStructs.N.init)))
        #expect(containsAllOf((1...3).map(TestStructs.N.init), where: { $0.g == $1.g }).matches([1, 2, 3].map(TestStructs.N.init)))
        #expect(containsAllOf((1...3).map(TestStructs.N.init), where: { $0.g == $1.g }).matches([1, 2, 3, 4, 5].map(TestStructs.N.init)))
        #expect(!containsAllOf((1...3).map(TestStructs.N.init), where: { $0.g == $1.g }).matches([4, 5, 6, 0].map(TestStructs.N.init)))
        #expect(!containsAllOf((1...3).map(TestStructs.N.init), where: { $0.g == $1.g }).matches([3].map(TestStructs.N.init)))
    }

    @Test
    func containsAllOfEquatable() {
        #expect(!containsAllOf(values: .init(g: 1), .init(g: 3)).matches([2].map(TestStructs.E.init)))
        #expect(containsAllOf(values: .init(g: 1), .init(g: 3)).matches([1, 2, 3].map(TestStructs.E.init)))
        #expect(containsAllOf(values: .init(g: 1), .init(g: 3)).matches([1, 2, 3, 4, 5].map(TestStructs.E.init)))
        #expect(!containsAllOf(values: .init(g: 1), .init(g: 3)).matches([4, 5, 6, 0].map(TestStructs.E.init)))
        #expect(!containsAllOf(values: .init(g: 1), .init(g: 3)).matches([3].map(TestStructs.E.init)))

        #expect(!containsAllOf((1...3).map(TestStructs.E.init)).matches([2].map(TestStructs.E.init)))
        #expect(containsAllOf((1...3).map(TestStructs.E.init)).matches([1, 2, 3].map(TestStructs.E.init)))
        #expect(containsAllOf((1...3).map(TestStructs.E.init)).matches([1, 2, 3, 4, 5].map(TestStructs.E.init)))
        #expect(!containsAllOf((1...3).map(TestStructs.E.init)).matches([4, 5, 6, 0].map(TestStructs.E.init)))
        #expect(!containsAllOf((1...3).map(TestStructs.E.init)).matches([3].map(TestStructs.E.init)))
    }

    @Test
    func containsAllOfHashable() {
        #expect(!containsAllOf(values: .init(g: 1), .init(g: 3)).matches([2].map(TestStructs.H.init)))
        #expect(containsAllOf(values: .init(g: 1), .init(g: 3)).matches([1, 2, 3].map(TestStructs.H.init)))
        #expect(containsAllOf(values: .init(g: 1), .init(g: 3)).matches([1, 2, 3, 4, 5].map(TestStructs.H.init)))
        #expect(!containsAllOf(values: .init(g: 1), .init(g: 3)).matches([4, 5, 6, 0].map(TestStructs.H.init)))
        #expect(!containsAllOf(values: .init(g: 1), .init(g: 3)).matches([3].map(TestStructs.H.init)))

        #expect(!containsAllOf((1...3).map(TestStructs.H.init)).matches([2].map(TestStructs.H.init)))
        #expect(containsAllOf((1...3).map(TestStructs.H.init)).matches([1, 2, 3].map(TestStructs.H.init)))
        #expect(containsAllOf((1...3).map(TestStructs.H.init)).matches([1, 2, 3, 4, 5].map(TestStructs.H.init)))
        #expect(!containsAllOf((1...3).map(TestStructs.H.init)).matches([4, 5, 6, 0].map(TestStructs.H.init)))
        #expect(!containsAllOf((1...3).map(TestStructs.H.init)).matches([3].map(TestStructs.H.init)))
    }

    @Test
    func containsAllOfMultiple() {
        #expect(!containsAllOf(values: 1, 3, 2, 2, 1).matches([2]))
        #expect(!containsAllOf(values: 1, 3, 2, 2, 1).matches([1, 2, 3]))
        #expect(!containsAllOf(values: 1, 3, 2, 2, 1).matches([1, 3, 2, 2]))
        #expect(containsAllOf(values: 1, 3, 2, 2, 1).matches([1, 3, 2, 2, 1]))

        #expect(!containsAllOf([1, 3, 2, 2, 1]).matches([2]))
        #expect(!containsAllOf([1, 3, 2, 2, 1]).matches([1, 2, 3]))
        #expect(!containsAllOf([1, 3, 2, 2, 1]).matches([1, 3, 2, 2]))
        #expect(containsAllOf([1, 3, 2, 2, 1]).matches([1, 3, 2, 2, 1]))
    }

    /// The matched sequence may hold an element more often than the matcher asks for it, as with the `Equatable`
    /// overload.
    @Test
    func containsAllOfAllowsExtraCopies() {
        #expect(containsAllOf(values: 1, 2).matches([1, 1, 2]))
        #expect(containsAllOf([1, 2]).matches([2, 1, 2, 1]))
        #expect(containsAllOf(values: TestStructs.H(g: 1)).matches([1, 1].map(TestStructs.H.init)))
        #expect(containsAllOf(values: TestStructs.E(g: 1)).matches([1, 1].map(TestStructs.E.init)))
        #expect(!containsAllOf(values: 1, 1, 2).matches([1, 2]))
    }

    // MARK: - Contains NONE of the elements.
    @Test
    func testContainsNoneOf() {
        // Variadic parameters.
        #expect(containsNoneOf(values: .init(g: 1), .init(g: 3), where: { $0.g == $1.g }).matches([2].map(TestStructs.N.init)))
        #expect(!containsNoneOf(values: .init(g: 1), .init(g: 3), where: { $0.g == $1.g }).matches([1, 2, 3].map(TestStructs.N.init)))
        #expect(!containsNoneOf(values: .init(g: 1), .init(g: 3), where: { $0.g == $1.g }).matches([1, 2, 3, 4, 5].map(TestStructs.N.init)))
        #expect(containsNoneOf(values: .init(g: 1), .init(g: 3), where: { $0.g == $1.g }).matches([4, 5, 6, 0].map(TestStructs.N.init)))
        #expect(containsNoneOf(values: .init(g: 1), .init(g: 3), where: { $0.g == $1.g }).matches([].map(TestStructs.N.init)))

        // Passed by array.
        #expect(!containsNoneOf((1...3).map(TestStructs.N.init), where: { $0.g == $1.g }).matches([2].map(TestStructs.N.init)))
        #expect(!containsNoneOf((1...3).map(TestStructs.N.init), where: { $0.g == $1.g }).matches([1, 2, 3].map(TestStructs.N.init)))
        #expect(!containsNoneOf((1...3).map(TestStructs.N.init), where: { $0.g == $1.g }).matches([1, 2, 3, 4, 5].map(TestStructs.N.init)))
        #expect(containsNoneOf((1...3).map(TestStructs.N.init), where: { $0.g == $1.g }).matches([4, 5, 6, 0].map(TestStructs.N.init)))
        #expect(containsNoneOf((1...3).map(TestStructs.N.init), where: { $0.g == $1.g }).matches([].map(TestStructs.N.init)))
    }

    @Test
    func containsNoneOfEquatable() {
        #expect(containsNoneOf(values: .init(g: 1), .init(g: 3)).matches([2].map(TestStructs.E.init)))
        #expect(!containsNoneOf(values: .init(g: 1), .init(g: 3)).matches([1, 2, 3].map(TestStructs.E.init)))
        #expect(!containsNoneOf(values: .init(g: 1), .init(g: 3)).matches([1, 2, 3, 4, 5].map(TestStructs.E.init)))
        #expect(containsNoneOf(values: .init(g: 1), .init(g: 3)).matches([4, 5, 6, 0].map(TestStructs.E.init)))
        #expect(containsNoneOf(values: .init(g: 1), .init(g: 3)).matches([].map(TestStructs.E.init)))

        #expect(!containsNoneOf((1...3).map(TestStructs.E.init)).matches([2].map(TestStructs.E.init)))
        #expect(!containsNoneOf((1...3).map(TestStructs.E.init)).matches([1, 2, 3].map(TestStructs.E.init)))
        #expect(!containsNoneOf((1...3).map(TestStructs.E.init)).matches([1, 2, 3, 4, 5].map(TestStructs.E.init)))
        #expect(containsNoneOf((1...3).map(TestStructs.E.init)).matches([4, 5, 6, 0].map(TestStructs.E.init)))
        #expect(containsNoneOf((1...3).map(TestStructs.E.init)).matches([].map(TestStructs.E.init)))
    }

    @Test
    func containsNoneOfHashable() {
        #expect(containsNoneOf(values: .init(g: 1), .init(g: 3)).matches([2].map(TestStructs.H.init)))
        #expect(!containsNoneOf(values: .init(g: 1), .init(g: 3)).matches([1, 2, 3].map(TestStructs.H.init)))
        #expect(!containsNoneOf(values: .init(g: 1), .init(g: 3)).matches([1, 2, 3, 4, 5].map(TestStructs.H.init)))
        #expect(containsNoneOf(values: .init(g: 1), .init(g: 3)).matches([4, 5, 6, 0].map(TestStructs.H.init)))
        #expect(containsNoneOf(values: .init(g: 1), .init(g: 3)).matches([].map(TestStructs.H.init)))

        #expect(!containsNoneOf((1...3).map(TestStructs.H.init)).matches([2].map(TestStructs.H.init)))
        #expect(!containsNoneOf((1...3).map(TestStructs.H.init)).matches([1, 2, 3].map(TestStructs.H.init)))
        #expect(!containsNoneOf((1...3).map(TestStructs.H.init)).matches([1, 2, 3, 4, 5].map(TestStructs.H.init)))
        #expect(containsNoneOf((1...3).map(TestStructs.H.init)).matches([4, 5, 6, 0].map(TestStructs.H.init)))
        #expect(containsNoneOf((1...3).map(TestStructs.H.init)).matches([].map(TestStructs.H.init)))
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
}
