import Testing
import Cuckoo

struct DictionaryParameterMatcherTest {
    // MARK: - Contains ANY of the elements as key-value pairs.
    @Test
    func testContainsAnyOf() {
        // With keys identical to values.
        #expect(!containsAnyOf([1, 3].toDictionaryAsKeysWithHashable()).matches([2].toDictionaryAsKeysWithHashable()))
        #expect(containsAnyOf([1, 3].toDictionaryAsKeysWithEquatable()).matches([1, 2].toDictionaryAsKeysWithEquatable()))
        #expect(!containsAnyOf([1, 3].toDictionaryAsKeysWithNonEquatable(), where: { $0.g == $1.g }).matches([0, 2].toDictionaryAsKeysWithNonEquatable()))
        #expect(containsAnyOf([1, 3].toDictionaryAsKeysWithEquatable()).matches([1, 3].toDictionaryAsKeysWithEquatable()))
        #expect(containsAnyOf([1, 3].toDictionaryAsKeysWithHashable()).matches([1, 2, 3].toDictionaryAsKeysWithHashable()))

        // With keys different from values.
        #expect(!containsAnyOf([1, 3].toDictionaryAsKeysWithHashable({ ($0, .init(g: $0 - 1)) })).matches([2].toDictionaryAsKeysWithHashable()))
        #expect(containsAnyOf([1, 3].toDictionaryAsKeysWithEquatable({ ($0, .init(g: $0 - 1)) })).matches([1, 2].toDictionaryAsKeysWithEquatable({ ($0, .init(g: $0 - 1)) })))
        #expect(!containsAnyOf([1, 3].toDictionaryAsKeysWithNonEquatable({ ($0, .init(g: $0 - 1)) }), where: { $0.g == $1.g }).matches([0, 2].toDictionaryAsKeysWithNonEquatable()))
        #expect(containsAnyOf([1, 3].toDictionaryAsKeysWithEquatable({ ($0, .init(g: $0 - 1)) })).matches([1, 3].toDictionaryAsKeysWithEquatable({ ($0, .init(g: $0 - 1)) })))
        #expect(containsAnyOf([1, 3].toDictionaryAsKeysWithHashable({ ($0, .init(g: $0 - 1)) })).matches([1, 2, 3].toDictionaryAsKeysWithHashable({ ($0, .init(g: $0 - 1)) })))
    }

    // MARK: - Contains ALL of the elements as key-value pairs.
    @Test
    func testContainsAllOf() {
        #expect(!containsAllOf([1, 3].toDictionaryAsKeysWithHashable()).matches([2].toDictionaryAsKeysWithHashable()))
        #expect(!containsAllOf([1, 3].toDictionaryAsKeysWithEquatable()).matches([1, 2].toDictionaryAsKeysWithEquatable()))
        #expect(!containsAllOf([1, 3].toDictionaryAsKeysWithNonEquatable(), where: { $0.g == $1.g }).matches([0, 2].toDictionaryAsKeysWithNonEquatable()))
        #expect(containsAllOf([1, 3].toDictionaryAsKeysWithEquatable()).matches([1, 3].toDictionaryAsKeysWithEquatable()))
        #expect(containsAllOf([1, 3].toDictionaryAsKeysWithHashable()).matches([1, 2, 3].toDictionaryAsKeysWithHashable()))

        #expect(!containsAllOf([1, 3].toDictionaryAsKeysWithHashable({ ($0, .init(g: $0 - 1)) })).matches([2].toDictionaryAsKeysWithHashable()))
        #expect(!containsAllOf([1, 3].toDictionaryAsKeysWithEquatable({ ($0, .init(g: $0 - 1)) })).matches([1, 2].toDictionaryAsKeysWithEquatable({ ($0, .init(g: $0 - 1)) })))
        #expect(!containsAllOf([1, 3].toDictionaryAsKeysWithNonEquatable({ ($0, .init(g: $0 - 1)) }), where: { $0.g == $1.g }).matches([0, 2].toDictionaryAsKeysWithNonEquatable()))
        #expect(containsAllOf([1, 3].toDictionaryAsKeysWithEquatable({ ($0, .init(g: $0 - 1)) })).matches([1, 3].toDictionaryAsKeysWithEquatable({ ($0, .init(g: $0 - 1)) })))
        #expect(containsAllOf([1, 3].toDictionaryAsKeysWithHashable({ ($0, .init(g: $0 - 1)) })).matches([1, 2, 3].toDictionaryAsKeysWithHashable({ ($0, .init(g: $0 - 1)) })))
    }

    // MARK: - Contains NONE of the elements as key-value pairs.
    @Test
    func testContainsNoneOf() {
        // With keys identical to values.
        #expect(containsNoneOf([1, 3].toDictionaryAsKeysWithHashable()).matches([2].toDictionaryAsKeysWithHashable()))
        #expect(!containsNoneOf([1, 3].toDictionaryAsKeysWithEquatable()).matches([1, 2].toDictionaryAsKeysWithEquatable()))
        #expect(containsNoneOf([1, 3].toDictionaryAsKeysWithNonEquatable(), where: { $0.g == $1.g }).matches([0, 2].toDictionaryAsKeysWithNonEquatable()))
        #expect(!containsNoneOf([1, 3].toDictionaryAsKeysWithEquatable()).matches([1, 3].toDictionaryAsKeysWithEquatable()))
        #expect(!containsNoneOf([1, 3].toDictionaryAsKeysWithHashable()).matches([1, 2, 3].toDictionaryAsKeysWithHashable()))

        // With keys different from values.
        #expect(containsNoneOf([1, 3].toDictionaryAsKeysWithHashable({ ($0, .init(g: $0 - 1)) })).matches([2].toDictionaryAsKeysWithHashable()))
        #expect(!containsNoneOf([1, 3].toDictionaryAsKeysWithEquatable({ ($0, .init(g: $0 - 1)) })).matches([1, 2].toDictionaryAsKeysWithEquatable({ ($0, .init(g: $0 - 1)) })))
        #expect(containsNoneOf([1, 3].toDictionaryAsKeysWithNonEquatable({ ($0, .init(g: $0 - 1)) }), where: { $0.g == $1.g }).matches([0, 2].toDictionaryAsKeysWithNonEquatable()))
        #expect(!containsNoneOf([1, 3].toDictionaryAsKeysWithEquatable({ ($0, .init(g: $0 - 1)) })).matches([1, 3].toDictionaryAsKeysWithEquatable({ ($0, .init(g: $0 - 1)) })))
        #expect(!containsNoneOf([1, 3].toDictionaryAsKeysWithHashable({ ($0, .init(g: $0 - 1)) })).matches([1, 2, 3].toDictionaryAsKeysWithHashable({ ($0, .init(g: $0 - 1)) })))
    }

    // MARK: - Contains ANY of the elements as keys.
    @Test
    func testContainsAnyKeysOf() {
        // Variadic parameters.
        #expect(!containsAnyKeysOf(values: 1, 3).matches([2].toDictionaryAsKeysWithHashable()))
        #expect(containsAnyKeysOf(values: 1, 3).matches([1, 2].toDictionaryAsKeysWithEquatable()))
        #expect(!containsAnyKeysOf(values: 1, 3).matches([0, 2].toDictionaryAsKeysWithNonEquatable()))
        #expect(containsAnyKeysOf(values: 1, 3).matches([1, 3].toDictionaryAsKeysWithEquatable()))
        #expect(containsAnyKeysOf(values: 1, 3).matches([1, 2, 3].toDictionaryAsKeysWithHashable()))

        // Passed by array.
        #expect(!containsAnyKeysOf([1, 3]).matches([2].toDictionaryAsKeysWithHashable()))
        #expect(containsAnyKeysOf([1, 3]).matches([1, 2].toDictionaryAsKeysWithEquatable()))
        #expect(!containsAnyKeysOf([1, 3]).matches([0, 2].toDictionaryAsKeysWithNonEquatable()))
        #expect(containsAnyKeysOf([1, 3]).matches([1, 3].toDictionaryAsKeysWithEquatable()))
        #expect(containsAnyKeysOf([1, 3]).matches([1, 2, 3].toDictionaryAsKeysWithHashable()))
    }

    // MARK: - Contains ALL of the elements as keys.
    @Test
    func testContainsAllKeysOf() {
        // Variadic parameters.
        #expect(!containsAllKeysOf(values: 1, 3).matches([2].toDictionaryAsKeysWithHashable()))
        #expect(!containsAllKeysOf(values: 1, 3).matches([1, 2].toDictionaryAsKeysWithEquatable()))
        #expect(!containsAllKeysOf(values: 1, 3).matches([0, 2].toDictionaryAsKeysWithNonEquatable()))
        #expect(containsAllKeysOf(values: 1, 3).matches([1, 3].toDictionaryAsKeysWithEquatable()))
        #expect(containsAllKeysOf(values: 1, 3).matches([1, 2, 3].toDictionaryAsKeysWithHashable()))

        // Passed by array.
        #expect(!containsAllKeysOf([1, 3]).matches([2].toDictionaryAsKeysWithHashable()))
        #expect(!containsAllKeysOf([1, 3]).matches([1, 2].toDictionaryAsKeysWithEquatable()))
        #expect(!containsAllKeysOf([1, 3]).matches([0, 2].toDictionaryAsKeysWithNonEquatable()))
        #expect(containsAllKeysOf([1, 3]).matches([1, 3].toDictionaryAsKeysWithEquatable()))
        #expect(containsAllKeysOf([1, 3]).matches([1, 2, 3].toDictionaryAsKeysWithHashable()))
    }

    // MARK: - Contains NONE of the elements as keys.
    @Test
    func testContainsNoKeysOf() {
        // Variadic parameters.
        #expect(containsNoKeysOf(values: 1, 3).matches([2].toDictionaryAsKeysWithHashable()))
        #expect(!containsNoKeysOf(values: 1, 3).matches([1, 2].toDictionaryAsKeysWithEquatable()))
        #expect(containsNoKeysOf(values: 1, 3).matches([0, 2].toDictionaryAsKeysWithNonEquatable()))
        #expect(!containsNoKeysOf(values: 1, 3).matches([1, 3].toDictionaryAsKeysWithEquatable()))
        #expect(!containsNoKeysOf(values: 1, 3).matches([1, 2, 3].toDictionaryAsKeysWithHashable()))

        // Passed by array.
        #expect(containsNoKeysOf([1, 3]).matches([2].toDictionaryAsKeysWithHashable()))
        #expect(!containsNoKeysOf([1, 3]).matches([1, 2].toDictionaryAsKeysWithEquatable()))
        #expect(containsNoKeysOf([1, 3]).matches([0, 2].toDictionaryAsKeysWithNonEquatable()))
        #expect(!containsNoKeysOf([1, 3]).matches([1, 3].toDictionaryAsKeysWithEquatable()))
        #expect(!containsNoKeysOf([1, 3]).matches([1, 2, 3].toDictionaryAsKeysWithHashable()))
    }

    // MARK: - Contains ANY of the elements as values.
    @Test
    func testContainsAnyValuesOf() {
        // Variadic parameters.
        #expect(!containsAnyValuesOf(values: .init(g: 1), .init(g: 3)).matches([2].toDictionaryAsKeysWithHashable()))
        #expect(containsAnyValuesOf(values: .init(g: 1), .init(g: 3)).matches([1, 2].toDictionaryAsKeysWithEquatable()))
        #expect(!containsAnyValuesOf(values: .init(g: 1), .init(g: 3), where: { $0.g == $1.g }).matches([0, 2].toDictionaryAsKeysWithNonEquatable()))
        #expect(containsAnyValuesOf(values: .init(g: 1), .init(g: 3)).matches([1, 3].toDictionaryAsKeysWithEquatable()))
        #expect(containsAnyValuesOf(values: .init(g: 1), .init(g: 3)).matches([1, 2, 3].toDictionaryAsKeysWithHashable()))

        // Passed by array.
        #expect(!containsAnyValuesOf([1, 3].map(TestStructs.H.init)).matches([2].toDictionaryAsKeysWithHashable()))
        #expect(containsAnyValuesOf([1, 3].map(TestStructs.E.init)).matches([1, 2].toDictionaryAsKeysWithEquatable()))
        #expect(!containsAnyValuesOf([1, 3].map(TestStructs.N.init), where: { $0.g == $1.g }).matches([0, 2].toDictionaryAsKeysWithNonEquatable()))
        #expect(containsAnyValuesOf([1, 3].map(TestStructs.E.init)).matches([1, 3].toDictionaryAsKeysWithEquatable()))
        #expect(containsAnyValuesOf([1, 3].map(TestStructs.H.init)).matches([1, 2, 3].toDictionaryAsKeysWithHashable()))

        #expect(containsAnyValuesOf([.init(g: 1), .init(g: 3)])
                .matches([2: TestStructs.H(g: 3), 3: .init(g: 1)]))
        #expect(containsAnyValuesOf([.init(g: 1), .init(g: 3)])
                .matches([2: TestStructs.H(g: 3), 3: .init(g: 4)]))
        #expect(containsAnyValuesOf([.init(g: 1), .init(g: 3)])
                .matches([1: TestStructs.H(g: 3)]))
        #expect(containsAnyValuesOf([.init(g: 1), .init(g: 3)])
                .matches([1: TestStructs.H(g: 1)]))
        #expect(!containsAnyValuesOf([.init(g: 1), .init(g: 3)])
                .matches([2: TestStructs.H(g: -3)]))
    }

    // MARK: - Contains ALL of the elements as values.
    @Test
    func testContainsAllValuesOf() {
        // Variadic parameters.
        #expect(!containsAllValuesOf(values: .init(g: 1), .init(g: 3)).matches([2].toDictionaryAsKeysWithHashable()))
        #expect(!containsAllValuesOf(values: .init(g: 1), .init(g: 3)).matches([1, 2].toDictionaryAsKeysWithEquatable()))
        #expect(!containsAllValuesOf(values: .init(g: 1), .init(g: 3), where: { $0.g == $1.g }).matches([0, 2].toDictionaryAsKeysWithNonEquatable()))
        #expect(containsAllValuesOf(values: .init(g: 1), .init(g: 3)).matches([1, 3].toDictionaryAsKeysWithEquatable()))
        #expect(containsAllValuesOf(values: .init(g: 1), .init(g: 3)).matches([1, 2, 3].toDictionaryAsKeysWithHashable()))

        // Passed by array.
        #expect(!containsAllValuesOf([1, 3].map(TestStructs.H.init)).matches([2].toDictionaryAsKeysWithHashable()))
        #expect(!containsAllValuesOf([1, 3].map(TestStructs.E.init)).matches([1, 2].toDictionaryAsKeysWithEquatable()))
        #expect(!containsAllValuesOf([1, 3].map(TestStructs.N.init), where: { $0.g == $1.g }).matches([0, 2].toDictionaryAsKeysWithNonEquatable()))
        #expect(containsAllValuesOf([1, 3].map(TestStructs.E.init)).matches([1, 3].toDictionaryAsKeysWithEquatable()))
        #expect(containsAllValuesOf([1, 3].map(TestStructs.H.init)).matches([1, 2, 3].toDictionaryAsKeysWithHashable()))

        #expect(containsAllValuesOf([.init(g: 1), .init(g: 3)])
                .matches([2: TestStructs.H(g: 3), 3: .init(g: 1)]))
        #expect(!containsAllValuesOf([.init(g: 1), .init(g: 3)])
                .matches([2: TestStructs.H(g: 3), 3: .init(g: 4)]))
        #expect(containsAllValuesOf([.init(g: 1), .init(g: 3)])
                .matches([1: TestStructs.H(g: 3), 3: .init(g: 1)]))
        #expect(!containsAllValuesOf([.init(g: 1), .init(g: 3)])
                .matches([1: TestStructs.H(g: 3), 2: TestStructs.H(g: 3), 3: TestStructs.H(g: 3)]))
        #expect(!containsAllValuesOf([.init(g: 1), .init(g: 3)])
                .matches([2: TestStructs.H(g: -3)]))
    }

    // MARK: - Contains NONE of the elements as values.
    @Test
    func testContainsNoValuesOf() {
        // Variadic parameters.
        #expect(containsNoValuesOf(values: .init(g: 1), .init(g: 3)).matches([2].toDictionaryAsKeysWithHashable()))
        #expect(!containsNoValuesOf(values: .init(g: 1), .init(g: 3)).matches([1, 2].toDictionaryAsKeysWithEquatable()))
        #expect(containsNoValuesOf(values: .init(g: 1), .init(g: 3), where: { $0.g == $1.g }).matches([0, 2].toDictionaryAsKeysWithNonEquatable()))
        #expect(!containsNoValuesOf(values: .init(g: 1), .init(g: 3)).matches([1, 3].toDictionaryAsKeysWithEquatable()))
        #expect(!containsNoValuesOf(values: .init(g: 1), .init(g: 3)).matches([1, 2, 3].toDictionaryAsKeysWithHashable()))

        // Passed by array.
        #expect(containsNoValuesOf([1, 3].map(TestStructs.H.init)).matches([2].toDictionaryAsKeysWithHashable()))
        #expect(!containsNoValuesOf([1, 3].map(TestStructs.E.init)).matches([1, 2].toDictionaryAsKeysWithEquatable()))
        #expect(containsNoValuesOf([1, 3].map(TestStructs.N.init), where: { $0.g == $1.g }).matches([0, 2].toDictionaryAsKeysWithNonEquatable()))
        #expect(!containsNoValuesOf([1, 3].map(TestStructs.E.init)).matches([1, 3].toDictionaryAsKeysWithEquatable()))
        #expect(!containsNoValuesOf([1, 3].map(TestStructs.H.init)).matches([1, 2, 3].toDictionaryAsKeysWithHashable()))

        #expect(!containsNoValuesOf([.init(g: 1), .init(g: 3)])
                .matches([2: TestStructs.H(g: 3), 3: .init(g: 1)]))
        #expect(!containsNoValuesOf([.init(g: 1), .init(g: 3)])
                .matches([2: TestStructs.H(g: 3), 3: .init(g: 4)]))
        #expect(!containsNoValuesOf([.init(g: 1), .init(g: 3)])
                .matches([1: TestStructs.H(g: 3)]))
        #expect(!containsNoValuesOf([.init(g: 1), .init(g: 3)])
                .matches([1: TestStructs.H(g: 1)]))
        #expect(containsNoValuesOf([.init(g: 1), .init(g: 3)])
                .matches([2: TestStructs.H(g: -3)]))
    }

    // MARK: - Has length N (exact, at least, at most).
    @Test
    func hasLengthExact() {
        #expect(hasLength(exactly: 4).matches([1: 1, 2: 2, 3: 3, 4: 4]))
        #expect(!hasLength(exactly: 2).matches([1: 1, 2: 2, 3: 3, 4: 4]))
        #expect(hasLength(exactly: 0).matches([:]))
    }

    @Test
    func hasLengthAtLeast() {
        #expect(hasLength(atLeast: 4).matches([1: 1, 2: 2, 3: 3, 4: 4]))
        #expect(hasLength(atLeast: 2).matches([1: 1, 2: 2, 3: 3, 4: 4]))
        #expect(hasLength(atLeast: 0).matches([:]))

        #expect(!hasLength(atLeast: 4, inclusive: false).matches([1: 1, 2: 2, 3: 3, 4: 4]))
        #expect(hasLength(atLeast: 2, inclusive: false).matches([1: 1, 2: 2, 3: 3, 4: 4]))
        #expect(!hasLength(atLeast: 0, inclusive: false).matches([:]))
    }

    @Test
    func hasLengthAtMost() {
        #expect(hasLength(atMost: 4).matches([1: 1, 2: 2, 3: 3, 4: 4]))
        #expect(!hasLength(atMost: 2).matches([1: 1, 2: 2, 3: 3, 4: 4]))
        #expect(hasLength(atMost: 0).matches([:]))

        #expect(hasLength(atMost: 5, inclusive: false).matches([1, 2, 3, 4]))
        #expect(!hasLength(atMost: 2, inclusive: false).matches([1, 2, 3, 4]))
        #expect(!hasLength(atMost: 0, inclusive: false).matches([:]))
    }
}

extension Array where Element == Int {
    func toDictionaryAsKeysAndValues(_ constructor: (Int) -> (Int, Int) = { ($0, $0) }) -> [Int: Int] {
        return Dictionary(uniqueKeysWithValues: map(constructor))
    }

    func toDictionaryAsKeysWithNonEquatable(_ constructor: (Int) -> (Int, TestStructs.N) = { ($0, TestStructs.N(g: $0)) }) -> [Int: TestStructs.N] {
        return Dictionary(uniqueKeysWithValues: map(constructor))
    }

    func toDictionaryAsKeysWithEquatable(_ constructor: (Int) -> (Int, TestStructs.E) = { ($0, TestStructs.E(g: $0)) }) -> [Int: TestStructs.E] {
        return Dictionary(uniqueKeysWithValues: map(constructor))
    }

    func toDictionaryAsKeysWithHashable(_ constructor: (Int) -> (Int, TestStructs.H) = { ($0, TestStructs.H(g: $0)) }) -> [Int: TestStructs.H] {
        return Dictionary(uniqueKeysWithValues: map(constructor))
    }
}
