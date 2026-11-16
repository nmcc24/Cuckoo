import Testing
import Cuckoo

struct DictionaryParameterMatcherTest {
    // MARK: - Contains ANY of the elements as key-value pairs.
    @Test
    func testContainsAnyOf() {
        // With keys identical to values.
        #expect(!bothOverloads(containsAnyOf([1, 3].toDictionaryAsKeysWithHashable()), containsAnyOf([1, 3].toDictionaryAsKeysWithHashable())).matches([2].toDictionaryAsKeysWithHashable()))
        #expect(bothOverloads(containsAnyOf([1, 3].toDictionaryAsKeysWithEquatable()), containsAnyOf([1, 3].toDictionaryAsKeysWithEquatable())).matches([1, 2].toDictionaryAsKeysWithEquatable()))
        #expect(!bothOverloads(containsAnyOf([1, 3].toDictionaryAsKeysWithNonEquatable(), where: { $0.g == $1.g }), containsAnyOf([1, 3].toDictionaryAsKeysWithNonEquatable(), where: { $0.g == $1.g })).matches([0, 2].toDictionaryAsKeysWithNonEquatable()))
        #expect(bothOverloads(containsAnyOf([1, 3].toDictionaryAsKeysWithEquatable()), containsAnyOf([1, 3].toDictionaryAsKeysWithEquatable())).matches([1, 3].toDictionaryAsKeysWithEquatable()))
        #expect(bothOverloads(containsAnyOf([1, 3].toDictionaryAsKeysWithHashable()), containsAnyOf([1, 3].toDictionaryAsKeysWithHashable())).matches([1, 2, 3].toDictionaryAsKeysWithHashable()))

        // With keys different from values.
        #expect(!bothOverloads(containsAnyOf([1, 3].toDictionaryAsKeysWithHashable({ ($0, TestStructs.H(g: $0 - 1)) })), containsAnyOf([1, 3].toDictionaryAsKeysWithHashable({ ($0, TestStructs.H(g: $0 - 1)) }))).matches([2].toDictionaryAsKeysWithHashable()))
        #expect(bothOverloads(containsAnyOf([1, 3].toDictionaryAsKeysWithEquatable({ ($0, TestStructs.E(g: $0 - 1)) })), containsAnyOf([1, 3].toDictionaryAsKeysWithEquatable({ ($0, TestStructs.E(g: $0 - 1)) }))).matches([1, 2].toDictionaryAsKeysWithEquatable({ ($0, TestStructs.E(g: $0 - 1)) })))
        #expect(!bothOverloads(containsAnyOf([1, 3].toDictionaryAsKeysWithNonEquatable({ ($0, TestStructs.N(g: $0 - 1)) }), where: { $0.g == $1.g }), containsAnyOf([1, 3].toDictionaryAsKeysWithNonEquatable({ ($0, TestStructs.N(g: $0 - 1)) }), where: { $0.g == $1.g })).matches([0, 2].toDictionaryAsKeysWithNonEquatable()))
        #expect(bothOverloads(containsAnyOf([1, 3].toDictionaryAsKeysWithEquatable({ ($0, TestStructs.E(g: $0 - 1)) })), containsAnyOf([1, 3].toDictionaryAsKeysWithEquatable({ ($0, TestStructs.E(g: $0 - 1)) }))).matches([1, 3].toDictionaryAsKeysWithEquatable({ ($0, TestStructs.E(g: $0 - 1)) })))
        #expect(bothOverloads(containsAnyOf([1, 3].toDictionaryAsKeysWithHashable({ ($0, TestStructs.H(g: $0 - 1)) })), containsAnyOf([1, 3].toDictionaryAsKeysWithHashable({ ($0, TestStructs.H(g: $0 - 1)) }))).matches([1, 2, 3].toDictionaryAsKeysWithHashable({ ($0, TestStructs.H(g: $0 - 1)) })))
    }

    // MARK: - Contains ALL of the elements as key-value pairs.
    @Test
    func testContainsAllOf() {
        #expect(!bothOverloads(containsAllOf([1, 3].toDictionaryAsKeysWithHashable()), containsAllOf([1, 3].toDictionaryAsKeysWithHashable())).matches([2].toDictionaryAsKeysWithHashable()))
        #expect(!bothOverloads(containsAllOf([1, 3].toDictionaryAsKeysWithEquatable()), containsAllOf([1, 3].toDictionaryAsKeysWithEquatable())).matches([1, 2].toDictionaryAsKeysWithEquatable()))
        #expect(!bothOverloads(containsAllOf([1, 3].toDictionaryAsKeysWithNonEquatable(), where: { $0.g == $1.g }), containsAllOf([1, 3].toDictionaryAsKeysWithNonEquatable(), where: { $0.g == $1.g })).matches([0, 2].toDictionaryAsKeysWithNonEquatable()))
        #expect(bothOverloads(containsAllOf([1, 3].toDictionaryAsKeysWithEquatable()), containsAllOf([1, 3].toDictionaryAsKeysWithEquatable())).matches([1, 3].toDictionaryAsKeysWithEquatable()))
        #expect(bothOverloads(containsAllOf([1, 3].toDictionaryAsKeysWithHashable()), containsAllOf([1, 3].toDictionaryAsKeysWithHashable())).matches([1, 2, 3].toDictionaryAsKeysWithHashable()))

        #expect(!bothOverloads(containsAllOf([1, 3].toDictionaryAsKeysWithHashable({ ($0, TestStructs.H(g: $0 - 1)) })), containsAllOf([1, 3].toDictionaryAsKeysWithHashable({ ($0, TestStructs.H(g: $0 - 1)) }))).matches([2].toDictionaryAsKeysWithHashable()))
        #expect(!bothOverloads(containsAllOf([1, 3].toDictionaryAsKeysWithEquatable({ ($0, TestStructs.E(g: $0 - 1)) })), containsAllOf([1, 3].toDictionaryAsKeysWithEquatable({ ($0, TestStructs.E(g: $0 - 1)) }))).matches([1, 2].toDictionaryAsKeysWithEquatable({ ($0, TestStructs.E(g: $0 - 1)) })))
        #expect(!bothOverloads(containsAllOf([1, 3].toDictionaryAsKeysWithNonEquatable({ ($0, TestStructs.N(g: $0 - 1)) }), where: { $0.g == $1.g }), containsAllOf([1, 3].toDictionaryAsKeysWithNonEquatable({ ($0, TestStructs.N(g: $0 - 1)) }), where: { $0.g == $1.g })).matches([0, 2].toDictionaryAsKeysWithNonEquatable()))
        #expect(bothOverloads(containsAllOf([1, 3].toDictionaryAsKeysWithEquatable({ ($0, TestStructs.E(g: $0 - 1)) })), containsAllOf([1, 3].toDictionaryAsKeysWithEquatable({ ($0, TestStructs.E(g: $0 - 1)) }))).matches([1, 3].toDictionaryAsKeysWithEquatable({ ($0, TestStructs.E(g: $0 - 1)) })))
        #expect(bothOverloads(containsAllOf([1, 3].toDictionaryAsKeysWithHashable({ ($0, TestStructs.H(g: $0 - 1)) })), containsAllOf([1, 3].toDictionaryAsKeysWithHashable({ ($0, TestStructs.H(g: $0 - 1)) }))).matches([1, 2, 3].toDictionaryAsKeysWithHashable({ ($0, TestStructs.H(g: $0 - 1)) })))
    }

    // MARK: - Contains NONE of the elements as key-value pairs.
    @Test
    func testContainsNoneOf() {
        // With keys identical to values.
        #expect(bothOverloads(containsNoneOf([1, 3].toDictionaryAsKeysWithHashable()), containsNoneOf([1, 3].toDictionaryAsKeysWithHashable())).matches([2].toDictionaryAsKeysWithHashable()))
        #expect(!bothOverloads(containsNoneOf([1, 3].toDictionaryAsKeysWithEquatable()), containsNoneOf([1, 3].toDictionaryAsKeysWithEquatable())).matches([1, 2].toDictionaryAsKeysWithEquatable()))
        #expect(bothOverloads(containsNoneOf([1, 3].toDictionaryAsKeysWithNonEquatable(), where: { $0.g == $1.g }), containsNoneOf([1, 3].toDictionaryAsKeysWithNonEquatable(), where: { $0.g == $1.g })).matches([0, 2].toDictionaryAsKeysWithNonEquatable()))
        #expect(!bothOverloads(containsNoneOf([1, 3].toDictionaryAsKeysWithEquatable()), containsNoneOf([1, 3].toDictionaryAsKeysWithEquatable())).matches([1, 3].toDictionaryAsKeysWithEquatable()))
        #expect(!bothOverloads(containsNoneOf([1, 3].toDictionaryAsKeysWithHashable()), containsNoneOf([1, 3].toDictionaryAsKeysWithHashable())).matches([1, 2, 3].toDictionaryAsKeysWithHashable()))

        // With keys different from values.
        #expect(bothOverloads(containsNoneOf([1, 3].toDictionaryAsKeysWithHashable({ ($0, TestStructs.H(g: $0 - 1)) })), containsNoneOf([1, 3].toDictionaryAsKeysWithHashable({ ($0, TestStructs.H(g: $0 - 1)) }))).matches([2].toDictionaryAsKeysWithHashable()))
        #expect(!bothOverloads(containsNoneOf([1, 3].toDictionaryAsKeysWithEquatable({ ($0, TestStructs.E(g: $0 - 1)) })), containsNoneOf([1, 3].toDictionaryAsKeysWithEquatable({ ($0, TestStructs.E(g: $0 - 1)) }))).matches([1, 2].toDictionaryAsKeysWithEquatable({ ($0, TestStructs.E(g: $0 - 1)) })))
        #expect(bothOverloads(containsNoneOf([1, 3].toDictionaryAsKeysWithNonEquatable({ ($0, TestStructs.N(g: $0 - 1)) }), where: { $0.g == $1.g }), containsNoneOf([1, 3].toDictionaryAsKeysWithNonEquatable({ ($0, TestStructs.N(g: $0 - 1)) }), where: { $0.g == $1.g })).matches([0, 2].toDictionaryAsKeysWithNonEquatable()))
        #expect(!bothOverloads(containsNoneOf([1, 3].toDictionaryAsKeysWithEquatable({ ($0, TestStructs.E(g: $0 - 1)) })), containsNoneOf([1, 3].toDictionaryAsKeysWithEquatable({ ($0, TestStructs.E(g: $0 - 1)) }))).matches([1, 3].toDictionaryAsKeysWithEquatable({ ($0, TestStructs.E(g: $0 - 1)) })))
        #expect(!bothOverloads(containsNoneOf([1, 3].toDictionaryAsKeysWithHashable({ ($0, TestStructs.H(g: $0 - 1)) })), containsNoneOf([1, 3].toDictionaryAsKeysWithHashable({ ($0, TestStructs.H(g: $0 - 1)) }))).matches([1, 2, 3].toDictionaryAsKeysWithHashable({ ($0, TestStructs.H(g: $0 - 1)) })))
    }

    // MARK: - Contains ANY of the elements as keys.
    @Test
    func testContainsAnyKeysOf() {
        // Variadic parameters.
        #expect(!bothOverloads(containsAnyKeysOf(values: 1, 3), containsAnyKeysOf(values: 1, 3)).matches([2].toDictionaryAsKeysWithHashable()))
        #expect(bothOverloads(containsAnyKeysOf(values: 1, 3), containsAnyKeysOf(values: 1, 3)).matches([1, 2].toDictionaryAsKeysWithEquatable()))
        #expect(!bothOverloads(containsAnyKeysOf(values: 1, 3), containsAnyKeysOf(values: 1, 3)).matches([0, 2].toDictionaryAsKeysWithNonEquatable()))
        #expect(bothOverloads(containsAnyKeysOf(values: 1, 3), containsAnyKeysOf(values: 1, 3)).matches([1, 3].toDictionaryAsKeysWithEquatable()))
        #expect(bothOverloads(containsAnyKeysOf(values: 1, 3), containsAnyKeysOf(values: 1, 3)).matches([1, 2, 3].toDictionaryAsKeysWithHashable()))

        // Passed by array.
        #expect(!bothOverloads(containsAnyKeysOf([1, 3]), containsAnyKeysOf([1, 3])).matches([2].toDictionaryAsKeysWithHashable()))
        #expect(bothOverloads(containsAnyKeysOf([1, 3]), containsAnyKeysOf([1, 3])).matches([1, 2].toDictionaryAsKeysWithEquatable()))
        #expect(!bothOverloads(containsAnyKeysOf([1, 3]), containsAnyKeysOf([1, 3])).matches([0, 2].toDictionaryAsKeysWithNonEquatable()))
        #expect(bothOverloads(containsAnyKeysOf([1, 3]), containsAnyKeysOf([1, 3])).matches([1, 3].toDictionaryAsKeysWithEquatable()))
        #expect(bothOverloads(containsAnyKeysOf([1, 3]), containsAnyKeysOf([1, 3])).matches([1, 2, 3].toDictionaryAsKeysWithHashable()))
    }

    // MARK: - Contains ALL of the elements as keys.
    @Test
    func testContainsAllKeysOf() {
        // Variadic parameters.
        #expect(!bothOverloads(containsAllKeysOf(values: 1, 3), containsAllKeysOf(values: 1, 3)).matches([2].toDictionaryAsKeysWithHashable()))
        #expect(!bothOverloads(containsAllKeysOf(values: 1, 3), containsAllKeysOf(values: 1, 3)).matches([1, 2].toDictionaryAsKeysWithEquatable()))
        #expect(!bothOverloads(containsAllKeysOf(values: 1, 3), containsAllKeysOf(values: 1, 3)).matches([0, 2].toDictionaryAsKeysWithNonEquatable()))
        #expect(bothOverloads(containsAllKeysOf(values: 1, 3), containsAllKeysOf(values: 1, 3)).matches([1, 3].toDictionaryAsKeysWithEquatable()))
        #expect(bothOverloads(containsAllKeysOf(values: 1, 3), containsAllKeysOf(values: 1, 3)).matches([1, 2, 3].toDictionaryAsKeysWithHashable()))

        // Passed by array.
        #expect(!bothOverloads(containsAllKeysOf([1, 3]), containsAllKeysOf([1, 3])).matches([2].toDictionaryAsKeysWithHashable()))
        #expect(!bothOverloads(containsAllKeysOf([1, 3]), containsAllKeysOf([1, 3])).matches([1, 2].toDictionaryAsKeysWithEquatable()))
        #expect(!bothOverloads(containsAllKeysOf([1, 3]), containsAllKeysOf([1, 3])).matches([0, 2].toDictionaryAsKeysWithNonEquatable()))
        #expect(bothOverloads(containsAllKeysOf([1, 3]), containsAllKeysOf([1, 3])).matches([1, 3].toDictionaryAsKeysWithEquatable()))
        #expect(bothOverloads(containsAllKeysOf([1, 3]), containsAllKeysOf([1, 3])).matches([1, 2, 3].toDictionaryAsKeysWithHashable()))
    }

    // MARK: - Contains NONE of the elements as keys.
    @Test
    func testContainsNoKeysOf() {
        // Variadic parameters.
        #expect(bothOverloads(containsNoKeysOf(values: 1, 3), containsNoKeysOf(values: 1, 3)).matches([2].toDictionaryAsKeysWithHashable()))
        #expect(!bothOverloads(containsNoKeysOf(values: 1, 3), containsNoKeysOf(values: 1, 3)).matches([1, 2].toDictionaryAsKeysWithEquatable()))
        #expect(bothOverloads(containsNoKeysOf(values: 1, 3), containsNoKeysOf(values: 1, 3)).matches([0, 2].toDictionaryAsKeysWithNonEquatable()))
        #expect(!bothOverloads(containsNoKeysOf(values: 1, 3), containsNoKeysOf(values: 1, 3)).matches([1, 3].toDictionaryAsKeysWithEquatable()))
        #expect(!bothOverloads(containsNoKeysOf(values: 1, 3), containsNoKeysOf(values: 1, 3)).matches([1, 2, 3].toDictionaryAsKeysWithHashable()))

        // Passed by array.
        #expect(bothOverloads(containsNoKeysOf([1, 3]), containsNoKeysOf([1, 3])).matches([2].toDictionaryAsKeysWithHashable()))
        #expect(!bothOverloads(containsNoKeysOf([1, 3]), containsNoKeysOf([1, 3])).matches([1, 2].toDictionaryAsKeysWithEquatable()))
        #expect(bothOverloads(containsNoKeysOf([1, 3]), containsNoKeysOf([1, 3])).matches([0, 2].toDictionaryAsKeysWithNonEquatable()))
        #expect(!bothOverloads(containsNoKeysOf([1, 3]), containsNoKeysOf([1, 3])).matches([1, 3].toDictionaryAsKeysWithEquatable()))
        #expect(!bothOverloads(containsNoKeysOf([1, 3]), containsNoKeysOf([1, 3])).matches([1, 2, 3].toDictionaryAsKeysWithHashable()))
    }

    // MARK: - Contains ANY of the elements as values.
    @Test
    func testContainsAnyValuesOf() {
        // Variadic parameters.
        #expect(!bothOverloads(containsAnyValuesOf(values: TestStructs.H(g: 1), TestStructs.H(g: 3)), containsAnyValuesOf(values: TestStructs.H(g: 1), TestStructs.H(g: 3))).matches([2].toDictionaryAsKeysWithHashable()))
        #expect(bothOverloads(containsAnyValuesOf(values: TestStructs.E(g: 1), TestStructs.E(g: 3)), containsAnyValuesOf(values: TestStructs.E(g: 1), TestStructs.E(g: 3))).matches([1, 2].toDictionaryAsKeysWithEquatable()))
        #expect(!bothOverloads(containsAnyValuesOf(values: TestStructs.N(g: 1), TestStructs.N(g: 3), where: { $0.g == $1.g }), containsAnyValuesOf(values: TestStructs.N(g: 1), TestStructs.N(g: 3), where: { $0.g == $1.g })).matches([0, 2].toDictionaryAsKeysWithNonEquatable()))
        #expect(bothOverloads(containsAnyValuesOf(values: TestStructs.E(g: 1), TestStructs.E(g: 3)), containsAnyValuesOf(values: TestStructs.E(g: 1), TestStructs.E(g: 3))).matches([1, 3].toDictionaryAsKeysWithEquatable()))
        #expect(bothOverloads(containsAnyValuesOf(values: TestStructs.H(g: 1), TestStructs.H(g: 3)), containsAnyValuesOf(values: TestStructs.H(g: 1), TestStructs.H(g: 3))).matches([1, 2, 3].toDictionaryAsKeysWithHashable()))

        // Passed by array.
        #expect(!bothOverloads(containsAnyValuesOf([1, 3].map(TestStructs.H.init)), containsAnyValuesOf([1, 3].map(TestStructs.H.init))).matches([2].toDictionaryAsKeysWithHashable()))
        #expect(bothOverloads(containsAnyValuesOf([1, 3].map(TestStructs.E.init)), containsAnyValuesOf([1, 3].map(TestStructs.E.init))).matches([1, 2].toDictionaryAsKeysWithEquatable()))
        #expect(!bothOverloads(containsAnyValuesOf([1, 3].map(TestStructs.N.init), where: { $0.g == $1.g }), containsAnyValuesOf([1, 3].map(TestStructs.N.init), where: { $0.g == $1.g })).matches([0, 2].toDictionaryAsKeysWithNonEquatable()))
        #expect(bothOverloads(containsAnyValuesOf([1, 3].map(TestStructs.E.init)), containsAnyValuesOf([1, 3].map(TestStructs.E.init))).matches([1, 3].toDictionaryAsKeysWithEquatable()))
        #expect(bothOverloads(containsAnyValuesOf([1, 3].map(TestStructs.H.init)), containsAnyValuesOf([1, 3].map(TestStructs.H.init))).matches([1, 2, 3].toDictionaryAsKeysWithHashable()))

        #expect(bothOverloads(containsAnyValuesOf([TestStructs.H(g: 1), TestStructs.H(g: 3)]), containsAnyValuesOf([TestStructs.H(g: 1), TestStructs.H(g: 3)])).matches([2: TestStructs.H(g: 3), 3: TestStructs.H(g: 1)]))
        #expect(bothOverloads(containsAnyValuesOf([TestStructs.H(g: 1), TestStructs.H(g: 3)]), containsAnyValuesOf([TestStructs.H(g: 1), TestStructs.H(g: 3)])).matches([2: TestStructs.H(g: 3), 3: TestStructs.H(g: 4)]))
        #expect(bothOverloads(containsAnyValuesOf([TestStructs.H(g: 1), TestStructs.H(g: 3)]), containsAnyValuesOf([TestStructs.H(g: 1), TestStructs.H(g: 3)])).matches([1: TestStructs.H(g: 3)]))
        #expect(bothOverloads(containsAnyValuesOf([TestStructs.H(g: 1), TestStructs.H(g: 3)]), containsAnyValuesOf([TestStructs.H(g: 1), TestStructs.H(g: 3)])).matches([1: TestStructs.H(g: 1)]))
        #expect(!bothOverloads(containsAnyValuesOf([TestStructs.H(g: 1), TestStructs.H(g: 3)]), containsAnyValuesOf([TestStructs.H(g: 1), TestStructs.H(g: 3)])).matches([2: TestStructs.H(g: -3)]))
    }

    // MARK: - Contains ALL of the elements as values.
    @Test
    func testContainsAllValuesOf() {
        // Variadic parameters.
        #expect(!bothOverloads(containsAllValuesOf(values: TestStructs.H(g: 1), TestStructs.H(g: 3)), containsAllValuesOf(values: TestStructs.H(g: 1), TestStructs.H(g: 3))).matches([2].toDictionaryAsKeysWithHashable()))
        #expect(!bothOverloads(containsAllValuesOf(values: TestStructs.E(g: 1), TestStructs.E(g: 3)), containsAllValuesOf(values: TestStructs.E(g: 1), TestStructs.E(g: 3))).matches([1, 2].toDictionaryAsKeysWithEquatable()))
        #expect(!bothOverloads(containsAllValuesOf(values: TestStructs.N(g: 1), TestStructs.N(g: 3), where: { $0.g == $1.g }), containsAllValuesOf(values: TestStructs.N(g: 1), TestStructs.N(g: 3), where: { $0.g == $1.g })).matches([0, 2].toDictionaryAsKeysWithNonEquatable()))
        #expect(bothOverloads(containsAllValuesOf(values: TestStructs.E(g: 1), TestStructs.E(g: 3)), containsAllValuesOf(values: TestStructs.E(g: 1), TestStructs.E(g: 3))).matches([1, 3].toDictionaryAsKeysWithEquatable()))
        #expect(bothOverloads(containsAllValuesOf(values: TestStructs.H(g: 1), TestStructs.H(g: 3)), containsAllValuesOf(values: TestStructs.H(g: 1), TestStructs.H(g: 3))).matches([1, 2, 3].toDictionaryAsKeysWithHashable()))

        // Passed by array.
        #expect(!bothOverloads(containsAllValuesOf([1, 3].map(TestStructs.H.init)), containsAllValuesOf([1, 3].map(TestStructs.H.init))).matches([2].toDictionaryAsKeysWithHashable()))
        #expect(!bothOverloads(containsAllValuesOf([1, 3].map(TestStructs.E.init)), containsAllValuesOf([1, 3].map(TestStructs.E.init))).matches([1, 2].toDictionaryAsKeysWithEquatable()))
        #expect(!bothOverloads(containsAllValuesOf([1, 3].map(TestStructs.N.init), where: { $0.g == $1.g }), containsAllValuesOf([1, 3].map(TestStructs.N.init), where: { $0.g == $1.g })).matches([0, 2].toDictionaryAsKeysWithNonEquatable()))
        #expect(bothOverloads(containsAllValuesOf([1, 3].map(TestStructs.E.init)), containsAllValuesOf([1, 3].map(TestStructs.E.init))).matches([1, 3].toDictionaryAsKeysWithEquatable()))
        #expect(bothOverloads(containsAllValuesOf([1, 3].map(TestStructs.H.init)), containsAllValuesOf([1, 3].map(TestStructs.H.init))).matches([1, 2, 3].toDictionaryAsKeysWithHashable()))

        #expect(bothOverloads(containsAllValuesOf([TestStructs.H(g: 1), TestStructs.H(g: 3)]), containsAllValuesOf([TestStructs.H(g: 1), TestStructs.H(g: 3)])).matches([2: TestStructs.H(g: 3), 3: TestStructs.H(g: 1)]))
        #expect(!bothOverloads(containsAllValuesOf([TestStructs.H(g: 1), TestStructs.H(g: 3)]), containsAllValuesOf([TestStructs.H(g: 1), TestStructs.H(g: 3)])).matches([2: TestStructs.H(g: 3), 3: TestStructs.H(g: 4)]))
        #expect(bothOverloads(containsAllValuesOf([TestStructs.H(g: 1), TestStructs.H(g: 3)]), containsAllValuesOf([TestStructs.H(g: 1), TestStructs.H(g: 3)])).matches([1: TestStructs.H(g: 3), 3: TestStructs.H(g: 1)]))
        #expect(!bothOverloads(containsAllValuesOf([TestStructs.H(g: 1), TestStructs.H(g: 3)]), containsAllValuesOf([TestStructs.H(g: 1), TestStructs.H(g: 3)])).matches([1: TestStructs.H(g: 3), 2: TestStructs.H(g: 3), 3: TestStructs.H(g: 3)]))
        #expect(!bothOverloads(containsAllValuesOf([TestStructs.H(g: 1), TestStructs.H(g: 3)]), containsAllValuesOf([TestStructs.H(g: 1), TestStructs.H(g: 3)])).matches([2: TestStructs.H(g: -3)]))
    }

    // MARK: - Contains NONE of the elements as values.
    @Test
    func testContainsNoValuesOf() {
        // Variadic parameters.
        #expect(bothOverloads(containsNoValuesOf(values: TestStructs.H(g: 1), TestStructs.H(g: 3)), containsNoValuesOf(values: TestStructs.H(g: 1), TestStructs.H(g: 3))).matches([2].toDictionaryAsKeysWithHashable()))
        #expect(!bothOverloads(containsNoValuesOf(values: TestStructs.E(g: 1), TestStructs.E(g: 3)), containsNoValuesOf(values: TestStructs.E(g: 1), TestStructs.E(g: 3))).matches([1, 2].toDictionaryAsKeysWithEquatable()))
        #expect(bothOverloads(containsNoValuesOf(values: TestStructs.N(g: 1), TestStructs.N(g: 3), where: { $0.g == $1.g }), containsNoValuesOf(values: TestStructs.N(g: 1), TestStructs.N(g: 3), where: { $0.g == $1.g })).matches([0, 2].toDictionaryAsKeysWithNonEquatable()))
        #expect(!bothOverloads(containsNoValuesOf(values: TestStructs.E(g: 1), TestStructs.E(g: 3)), containsNoValuesOf(values: TestStructs.E(g: 1), TestStructs.E(g: 3))).matches([1, 3].toDictionaryAsKeysWithEquatable()))
        #expect(!bothOverloads(containsNoValuesOf(values: TestStructs.H(g: 1), TestStructs.H(g: 3)), containsNoValuesOf(values: TestStructs.H(g: 1), TestStructs.H(g: 3))).matches([1, 2, 3].toDictionaryAsKeysWithHashable()))

        // Passed by array.
        #expect(bothOverloads(containsNoValuesOf([1, 3].map(TestStructs.H.init)), containsNoValuesOf([1, 3].map(TestStructs.H.init))).matches([2].toDictionaryAsKeysWithHashable()))
        #expect(!bothOverloads(containsNoValuesOf([1, 3].map(TestStructs.E.init)), containsNoValuesOf([1, 3].map(TestStructs.E.init))).matches([1, 2].toDictionaryAsKeysWithEquatable()))
        #expect(bothOverloads(containsNoValuesOf([1, 3].map(TestStructs.N.init), where: { $0.g == $1.g }), containsNoValuesOf([1, 3].map(TestStructs.N.init), where: { $0.g == $1.g })).matches([0, 2].toDictionaryAsKeysWithNonEquatable()))
        #expect(!bothOverloads(containsNoValuesOf([1, 3].map(TestStructs.E.init)), containsNoValuesOf([1, 3].map(TestStructs.E.init))).matches([1, 3].toDictionaryAsKeysWithEquatable()))
        #expect(!bothOverloads(containsNoValuesOf([1, 3].map(TestStructs.H.init)), containsNoValuesOf([1, 3].map(TestStructs.H.init))).matches([1, 2, 3].toDictionaryAsKeysWithHashable()))

        #expect(!bothOverloads(containsNoValuesOf([TestStructs.H(g: 1), TestStructs.H(g: 3)]), containsNoValuesOf([TestStructs.H(g: 1), TestStructs.H(g: 3)])).matches([2: TestStructs.H(g: 3), 3: TestStructs.H(g: 1)]))
        #expect(!bothOverloads(containsNoValuesOf([TestStructs.H(g: 1), TestStructs.H(g: 3)]), containsNoValuesOf([TestStructs.H(g: 1), TestStructs.H(g: 3)])).matches([2: TestStructs.H(g: 3), 3: TestStructs.H(g: 4)]))
        #expect(!bothOverloads(containsNoValuesOf([TestStructs.H(g: 1), TestStructs.H(g: 3)]), containsNoValuesOf([TestStructs.H(g: 1), TestStructs.H(g: 3)])).matches([1: TestStructs.H(g: 3)]))
        #expect(!bothOverloads(containsNoValuesOf([TestStructs.H(g: 1), TestStructs.H(g: 3)]), containsNoValuesOf([TestStructs.H(g: 1), TestStructs.H(g: 3)])).matches([1: TestStructs.H(g: 1)]))
        #expect(bothOverloads(containsNoValuesOf([TestStructs.H(g: 1), TestStructs.H(g: 3)]), containsNoValuesOf([TestStructs.H(g: 1), TestStructs.H(g: 3)])).matches([2: TestStructs.H(g: -3)]))
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
