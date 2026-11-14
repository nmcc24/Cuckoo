extension Dictionary: _Matchable where Value: _Matchable, Value == Value.MatchedType {
    public typealias MatchedType = [Key: Value]

    public var matcher: ParameterMatcher<[Key: Value]> {
        let matchers = mapValues(\.matcher)
        return ParameterMatcher<[Key: Value]> { other in
            matchers.count == other.count && matchers.allSatisfy { key, matcher in
                other[key].map(matcher.matches) ?? false
            }
        }
    }
}

/// Keys must be matchable themselves, as a stand-in for `Sendable`, which a conditional conformance can't require.
extension Dictionary: _SendableMatchable
where Key: _SendableMatchable, Value: _SendableMatchable, Value == Value.MatchedType {
    public var sendableMatcher: SendableMatcher<[Key: Value]> {
        let matchers = mapValues(\.sendableMatcher)
        return SendableMatcher<[Key: Value]> { other in
            matchers.count == other.count && matchers.allSatisfy { key, matcher in
                other[key].map(matcher.matches) ?? false
            }
        }
    }
}

// Each matcher here comes in two kinds, as `equal(to:)` does: a `SendableMatcher` when the keys and values it keeps
// are `Sendable`, and a `ParameterMatcher` otherwise. A matcher that takes a `where:` closure prefers the
// `ParameterMatcher`, so the closure may capture non-`Sendable` state; a `Sendable` mock's stubs pick the
// `SendableMatcher`.


// MARK: PAIR MATCHING
// MARK: - Contains ANY of the elements as key-value pairs.
/**
 * Matcher for dictionaries that checks if the matching dictionary contains any of the key-value pairs from the passed dictionary.
 * - parameter inputDictionary: Dictionary that is used for matching.
 * - returns: A `ParameterMatcher`. When the values it keeps are `Sendable`, an overload returns a `SendableMatcher` instead.
 */
public func containsAnyOf<K, V: Equatable>(_ inputDictionary: [K: V]) -> ParameterMatcher<[K: V]> {
    ParameterMatcher { containsAnyPair($0, inputDictionary, where: ==) }
}

/**
 * Matcher for dictionaries that checks if the matching dictionary contains any of the key-value pairs from the passed dictionary.
 * - parameter inputDictionary: Dictionary that is used for matching.
 * - returns: A `SendableMatcher`, which a `Sendable` mock's stubs accept.
 */
public func containsAnyOf<K: Sendable, V: Equatable & Sendable>(_ inputDictionary: [K: V]) -> SendableMatcher<[K: V]> {
    SendableMatcher { containsAnyPair($0, inputDictionary, where: ==) }
}

/**
 * Matcher for dictionaries that checks if the matching dictionary contains any of the key-value pairs from the passed dictionary.
 * - parameter inputDictionary: Dictionary that is used for matching.
 * - parameter equality: Closure for determining equality of elements that don't conform to `Equatable`.
 * - returns: A `ParameterMatcher`. When the values it keeps are `Sendable`, an overload returns a `SendableMatcher` instead.
 */
public func containsAnyOf<K, V>(
    _ inputDictionary: [K: V],
    where equality: @escaping (V, V) -> Bool
) -> ParameterMatcher<[K: V]> {
    ParameterMatcher { containsAnyPair($0, inputDictionary, where: equality) }
}

/**
 * Matcher for dictionaries that checks if the matching dictionary contains any of the key-value pairs from the passed dictionary.
 * - parameter inputDictionary: Dictionary that is used for matching.
 * - parameter equality: Closure for determining equality of elements that don't conform to `Equatable`.
 * - returns: A `SendableMatcher`, which a `Sendable` mock's stubs accept.
 */
@_disfavoredOverload
public func containsAnyOf<K: Sendable, V: Sendable>(
    _ inputDictionary: [K: V],
    where equality: @escaping @Sendable (V, V) -> Bool
) -> SendableMatcher<[K: V]> {
    SendableMatcher { containsAnyPair($0, inputDictionary, where: equality) }
}

// MARK: - Contains ALL of the elements as key-value pairs.
/**
 * Matcher for dictionaries that checks if the matching dictionary contains all of the key-value pairs from the passed dictionary.
 * - parameter inputDictionary: Dictionary that is used for matching.
 * - returns: A `ParameterMatcher`. When the values it keeps are `Sendable`, an overload returns a `SendableMatcher` instead.
 */
public func containsAllOf<K, V: Equatable>(_ inputDictionary: [K: V]) -> ParameterMatcher<[K: V]> {
    ParameterMatcher { containsAllPairs($0, inputDictionary, where: ==) }
}

/**
 * Matcher for dictionaries that checks if the matching dictionary contains all of the key-value pairs from the passed dictionary.
 * - parameter inputDictionary: Dictionary that is used for matching.
 * - returns: A `SendableMatcher`, which a `Sendable` mock's stubs accept.
 */
public func containsAllOf<K: Sendable, V: Equatable & Sendable>(_ inputDictionary: [K: V]) -> SendableMatcher<[K: V]> {
    SendableMatcher { containsAllPairs($0, inputDictionary, where: ==) }
}

/**
 * Matcher for dictionaries that checks if the matching dictionary contains all of the key-value pairs from the passed dictionary.
 * - parameter inputDictionary: Dictionary that is used for matching.
 * - parameter equality: Closure for determining equality of elements that don't conform to `Equatable`.
 * - returns: A `ParameterMatcher`. When the values it keeps are `Sendable`, an overload returns a `SendableMatcher` instead.
 */
public func containsAllOf<K, V>(
    _ inputDictionary: [K: V],
    where equality: @escaping (V, V) -> Bool
) -> ParameterMatcher<[K: V]> {
    ParameterMatcher { containsAllPairs($0, inputDictionary, where: equality) }
}

/**
 * Matcher for dictionaries that checks if the matching dictionary contains all of the key-value pairs from the passed dictionary.
 * - parameter inputDictionary: Dictionary that is used for matching.
 * - parameter equality: Closure for determining equality of elements that don't conform to `Equatable`.
 * - returns: A `SendableMatcher`, which a `Sendable` mock's stubs accept.
 */
@_disfavoredOverload
public func containsAllOf<K: Sendable, V: Sendable>(
    _ inputDictionary: [K: V],
    where equality: @escaping @Sendable (V, V) -> Bool
) -> SendableMatcher<[K: V]> {
    SendableMatcher { containsAllPairs($0, inputDictionary, where: equality) }
}

// MARK: - Contains NONE of the elements as key-value pairs.
/**
 * Matcher for dictionaries that checks if the matching dictionary contains none of the key-value pairs from the passed dictionary.
 * - parameter inputDictionary: Dictionary that is used for matching.
 * - returns: A `ParameterMatcher`. When the values it keeps are `Sendable`, an overload returns a `SendableMatcher` instead.
 */
public func containsNoneOf<K, V: Equatable>(_ inputDictionary: [K: V]) -> ParameterMatcher<[K: V]> {
    ParameterMatcher { containsNoPair($0, inputDictionary, where: ==) }
}

/**
 * Matcher for dictionaries that checks if the matching dictionary contains none of the key-value pairs from the passed dictionary.
 * - parameter inputDictionary: Dictionary that is used for matching.
 * - returns: A `SendableMatcher`, which a `Sendable` mock's stubs accept.
 */
public func containsNoneOf<K: Sendable, V: Equatable & Sendable>(_ inputDictionary: [K: V]) -> SendableMatcher<[K: V]> {
    SendableMatcher { containsNoPair($0, inputDictionary, where: ==) }
}

/**
 * Matcher for dictionaries that checks if the matching dictionary contains none of the key-value pairs from the passed dictionary.
 * - parameter inputDictionary: Dictionary that is used for matching.
 * - parameter equality: Closure for determining equality of elements that don't conform to `Equatable`.
 * - returns: A `ParameterMatcher`. When the values it keeps are `Sendable`, an overload returns a `SendableMatcher` instead.
 */
public func containsNoneOf<K, V>(
    _ inputDictionary: [K: V],
    where equality: @escaping (V, V) -> Bool
) -> ParameterMatcher<[K: V]> {
    ParameterMatcher { containsNoPair($0, inputDictionary, where: equality) }
}

/**
 * Matcher for dictionaries that checks if the matching dictionary contains none of the key-value pairs from the passed dictionary.
 * - parameter inputDictionary: Dictionary that is used for matching.
 * - parameter equality: Closure for determining equality of elements that don't conform to `Equatable`.
 * - returns: A `SendableMatcher`, which a `Sendable` mock's stubs accept.
 */
@_disfavoredOverload
public func containsNoneOf<K: Sendable, V: Sendable>(
    _ inputDictionary: [K: V],
    where equality: @escaping @Sendable (V, V) -> Bool
) -> SendableMatcher<[K: V]> {
    SendableMatcher { containsNoPair($0, inputDictionary, where: equality) }
}


// MARK: KEYS MATCHING
// MARK: - Contains ANY of the elements as keys.
/**
 * Matcher for dictionaries that checks if the matching dictionary contains any of the passed keys.
 * - parameter elements: Variadic elements that are used for matching.
 * - returns: A `ParameterMatcher`. When the values it keeps are `Sendable`, an overload returns a `SendableMatcher` instead.
 */
public func containsAnyKeysOf<K, V>(values elements: K...) -> ParameterMatcher<[K: V]> {
    containsAnyKeysOf(elements)
}

/**
 * Matcher for dictionaries that checks if the matching dictionary contains any of the passed keys.
 * - parameter elements: Variadic elements that are used for matching.
 * - returns: A `SendableMatcher`, which a `Sendable` mock's stubs accept.
 */
public func containsAnyKeysOf<K: Sendable, V: SendableMetatype>(values elements: K...) -> SendableMatcher<[K: V]> {
    containsAnyKeysOf(elements)
}

/**
 * Matcher for dictionaries that checks if the matching dictionary contains any of the passed keys.
 * - parameter elements: Elements that are used for matching.
 * - returns: A `ParameterMatcher`. When the values it keeps are `Sendable`, an overload returns a `SendableMatcher` instead.
 */
public func containsAnyKeysOf<S: Sequence, V>(_ elements: S) -> ParameterMatcher<[S.Element: V]> {
    let keys = Set(elements)
    return ParameterMatcher { !keys.isDisjoint(with: $0.keys) }
}

/**
 * Matcher for dictionaries that checks if the matching dictionary contains any of the passed keys.
 * - parameter elements: Elements that are used for matching.
 * - returns: A `SendableMatcher`, which a `Sendable` mock's stubs accept.
 */
public func containsAnyKeysOf<S: Sequence, V: SendableMetatype>(_ elements: S) -> SendableMatcher<[S.Element: V]> where S.Element: Sendable {
    let keys = Set(elements)
    return SendableMatcher { !keys.isDisjoint(with: $0.keys) }
}

// MARK: - Contains ALL of the elements as keys.
/**
 * Matcher for dictionaries that checks if the matching dictionary contains all of the passed keys.
 * - parameter elements: Variadic elements that are used for matching.
 * - returns: A `ParameterMatcher`. When the values it keeps are `Sendable`, an overload returns a `SendableMatcher` instead.
 */
public func containsAllKeysOf<K, V>(values elements: K...) -> ParameterMatcher<[K: V]> {
    containsAllKeysOf(elements)
}

/**
 * Matcher for dictionaries that checks if the matching dictionary contains all of the passed keys.
 * - parameter elements: Variadic elements that are used for matching.
 * - returns: A `SendableMatcher`, which a `Sendable` mock's stubs accept.
 */
public func containsAllKeysOf<K: Sendable, V: SendableMetatype>(values elements: K...) -> SendableMatcher<[K: V]> {
    containsAllKeysOf(elements)
}

/**
 * Matcher for dictionaries that checks if the matching dictionary contains all of the passed keys.
 * - parameter elements: Elements that are used for matching.
 * - returns: A `ParameterMatcher`. When the values it keeps are `Sendable`, an overload returns a `SendableMatcher` instead.
 */
public func containsAllKeysOf<S: Sequence, V>(_ elements: S) -> ParameterMatcher<[S.Element: V]> {
    let keys = Set(elements)
    return ParameterMatcher { dictionary in keys.allSatisfy { dictionary[$0] != nil } }
}

/**
 * Matcher for dictionaries that checks if the matching dictionary contains all of the passed keys.
 * - parameter elements: Elements that are used for matching.
 * - returns: A `SendableMatcher`, which a `Sendable` mock's stubs accept.
 */
public func containsAllKeysOf<S: Sequence, V: SendableMetatype>(_ elements: S) -> SendableMatcher<[S.Element: V]> where S.Element: Sendable {
    let keys = Set(elements)
    return SendableMatcher { dictionary in keys.allSatisfy { dictionary[$0] != nil } }
}

// MARK: - Contains NONE of the elements as keys.
/**
 * Matcher for dictionaries that checks if the matching dictionary contains none of the passed keys.
 * - parameter elements: Variadic elements that are used for matching.
 * - returns: A `ParameterMatcher`. When the values it keeps are `Sendable`, an overload returns a `SendableMatcher` instead.
 */
public func containsNoKeysOf<K, V>(values elements: K...) -> ParameterMatcher<[K: V]> {
    containsNoKeysOf(elements)
}

/**
 * Matcher for dictionaries that checks if the matching dictionary contains none of the passed keys.
 * - parameter elements: Variadic elements that are used for matching.
 * - returns: A `SendableMatcher`, which a `Sendable` mock's stubs accept.
 */
public func containsNoKeysOf<K: Sendable, V: SendableMetatype>(values elements: K...) -> SendableMatcher<[K: V]> {
    containsNoKeysOf(elements)
}

/**
 * Matcher for dictionaries that checks if the matching dictionary contains none of the passed keys.
 * - parameter elements: Elements that are used for matching.
 * - returns: A `ParameterMatcher`. When the values it keeps are `Sendable`, an overload returns a `SendableMatcher` instead.
 */
public func containsNoKeysOf<S: Sequence, V>(_ elements: S) -> ParameterMatcher<[S.Element: V]> {
    let keys = Set(elements)
    return ParameterMatcher { keys.isDisjoint(with: $0.keys) }
}

/**
 * Matcher for dictionaries that checks if the matching dictionary contains none of the passed keys.
 * - parameter elements: Elements that are used for matching.
 * - returns: A `SendableMatcher`, which a `Sendable` mock's stubs accept.
 */
public func containsNoKeysOf<S: Sequence, V: SendableMetatype>(_ elements: S) -> SendableMatcher<[S.Element: V]> where S.Element: Sendable {
    let keys = Set(elements)
    return SendableMatcher { keys.isDisjoint(with: $0.keys) }
}


// MARK: VALUES MATCHING
// MARK: - Contains ANY of the elements as values.
/**
 * Matcher for dictionaries that checks if the matching dictionary contains any of the passed values.
 * - parameter elements: Variadic elements that are used for matching.
 * - parameter equality: Closure for determining equality of elements that don't conform to `Equatable`.
 * - returns: A `ParameterMatcher`. When the values it keeps are `Sendable`, an overload returns a `SendableMatcher` instead.
 */
public func containsAnyValuesOf<K, V>(
    values elements: V...,
    where equality: @escaping (V, V) -> Bool
) -> ParameterMatcher<[K: V]> {
    containsAnyValuesOf(elements, where: equality)
}

/**
 * Matcher for dictionaries that checks if the matching dictionary contains any of the passed values.
 * - parameter elements: Variadic elements that are used for matching.
 * - parameter equality: Closure for determining equality of elements that don't conform to `Equatable`.
 * - returns: A `SendableMatcher`, which a `Sendable` mock's stubs accept.
 */
@_disfavoredOverload
public func containsAnyValuesOf<K: SendableMetatype, V: Sendable>(
    values elements: V...,
    where equality: @escaping @Sendable (V, V) -> Bool
) -> SendableMatcher<[K: V]> {
    containsAnyValuesOf(elements, where: equality)
}

/**
 * Matcher for dictionaries that checks if the matching dictionary contains any of the passed values.
 * - parameter elements: Elements that are used for matching.
 * - parameter equality: Closure for determining equality of elements that don't conform to `Equatable`.
 * - returns: A `ParameterMatcher`. When the values it keeps are `Sendable`, an overload returns a `SendableMatcher` instead.
 */
public func containsAnyValuesOf<K, S: Sequence>(
    _ elements: S,
    where equality: @escaping (S.Element, S.Element) -> Bool
) -> ParameterMatcher<[K: S.Element]> {
    let elements = Array(elements)
    return ParameterMatcher { containsAny($0.values, elements, where: equality) }
}

/**
 * Matcher for dictionaries that checks if the matching dictionary contains any of the passed values.
 * - parameter elements: Elements that are used for matching.
 * - parameter equality: Closure for determining equality of elements that don't conform to `Equatable`.
 * - returns: A `SendableMatcher`, which a `Sendable` mock's stubs accept.
 */
@_disfavoredOverload
public func containsAnyValuesOf<K: SendableMetatype, S: Sequence>(
    _ elements: S,
    where equality: @escaping @Sendable (S.Element, S.Element) -> Bool
) -> SendableMatcher<[K: S.Element]> where S.Element: Sendable {
    let elements = Array(elements)
    return SendableMatcher { containsAny($0.values, elements, where: equality) }
}

/**
 * Matcher for dictionaries that checks if the matching dictionary contains any of the passed values.
 * - parameter elements: Variadic elements that are used for matching.
 * - returns: A `ParameterMatcher`. When the values it keeps are `Sendable`, an overload returns a `SendableMatcher` instead.
 */
public func containsAnyValuesOf<K, V: Equatable>(values elements: V...) -> ParameterMatcher<[K: V]> {
    containsAnyValuesOf(elements)
}

/**
 * Matcher for dictionaries that checks if the matching dictionary contains any of the passed values.
 * - parameter elements: Variadic elements that are used for matching.
 * - returns: A `SendableMatcher`, which a `Sendable` mock's stubs accept.
 */
public func containsAnyValuesOf<K: SendableMetatype, V: Equatable & Sendable>(values elements: V...) -> SendableMatcher<[K: V]> {
    containsAnyValuesOf(elements)
}

/**
 * Matcher for dictionaries that checks if the matching dictionary contains any of the passed values.
 * - parameter elements: Elements that are used for matching.
 * - returns: A `ParameterMatcher`. When the values it keeps are `Sendable`, an overload returns a `SendableMatcher` instead.
 */
public func containsAnyValuesOf<K, S: Sequence>(
    _ elements: S
) -> ParameterMatcher<[K: S.Element]> where S.Element: Equatable {
    let elements = Array(elements)
    return ParameterMatcher { containsAny($0.values, elements, where: ==) }
}

/**
 * Matcher for dictionaries that checks if the matching dictionary contains any of the passed values.
 * - parameter elements: Elements that are used for matching.
 * - returns: A `SendableMatcher`, which a `Sendable` mock's stubs accept.
 */
public func containsAnyValuesOf<K: SendableMetatype, S: Sequence>(
    _ elements: S
) -> SendableMatcher<[K: S.Element]> where S.Element: Equatable & Sendable {
    let elements = Array(elements)
    return SendableMatcher { containsAny($0.values, elements, where: ==) }
}

/**
 * Matcher for dictionaries that checks if the matching dictionary contains any of the passed values.
 * - parameter elements: Variadic elements that are used for matching.
 * - returns: A `ParameterMatcher`. When the values it keeps are `Sendable`, an overload returns a `SendableMatcher` instead.
 */
public func containsAnyValuesOf<K, V: Hashable>(values elements: V...) -> ParameterMatcher<[K: V]> {
    containsAnyValuesOf(elements)
}

/**
 * Matcher for dictionaries that checks if the matching dictionary contains any of the passed values.
 * - parameter elements: Variadic elements that are used for matching.
 * - returns: A `SendableMatcher`, which a `Sendable` mock's stubs accept.
 */
public func containsAnyValuesOf<K: SendableMetatype, V: Hashable & Sendable>(values elements: V...) -> SendableMatcher<[K: V]> {
    containsAnyValuesOf(elements)
}

/**
 * Matcher for dictionaries that checks if the matching dictionary contains any of the passed values.
 * - parameter elements: Elements that are used for matching.
 * - returns: A `ParameterMatcher`. When the values it keeps are `Sendable`, an overload returns a `SendableMatcher` instead.
 */
public func containsAnyValuesOf<K, S: Sequence>(
    _ elements: S
) -> ParameterMatcher<[K: S.Element]> where S.Element: Hashable {
    let values = Set(elements)
    return ParameterMatcher { !values.isDisjoint(with: $0.values) }
}

/**
 * Matcher for dictionaries that checks if the matching dictionary contains any of the passed values.
 * - parameter elements: Elements that are used for matching.
 * - returns: A `SendableMatcher`, which a `Sendable` mock's stubs accept.
 */
public func containsAnyValuesOf<K: SendableMetatype, S: Sequence>(
    _ elements: S
) -> SendableMatcher<[K: S.Element]> where S.Element: Hashable & Sendable {
    let values = Set(elements)
    return SendableMatcher { !values.isDisjoint(with: $0.values) }
}

// MARK: - Contains ALL of the elements as values.
/**
 * Matcher for dictionaries that checks if the matching dictionary contains all of the passed values.
 * - parameter elements: Variadic elements that are used for matching.
 * - parameter equality: Closure for determining equality of elements that don't conform to `Equatable`.
 * - returns: A `ParameterMatcher`. When the values it keeps are `Sendable`, an overload returns a `SendableMatcher` instead.
 */
public func containsAllValuesOf<K, V>(
    values elements: V...,
    where equality: @escaping (V, V) -> Bool
) -> ParameterMatcher<[K: V]> {
    containsAllValuesOf(elements, where: equality)
}

/**
 * Matcher for dictionaries that checks if the matching dictionary contains all of the passed values.
 * - parameter elements: Variadic elements that are used for matching.
 * - parameter equality: Closure for determining equality of elements that don't conform to `Equatable`.
 * - returns: A `SendableMatcher`, which a `Sendable` mock's stubs accept.
 */
@_disfavoredOverload
public func containsAllValuesOf<K: SendableMetatype, V: Sendable>(
    values elements: V...,
    where equality: @escaping @Sendable (V, V) -> Bool
) -> SendableMatcher<[K: V]> {
    containsAllValuesOf(elements, where: equality)
}

/**
 * Matcher for dictionaries that checks if the matching dictionary contains all of the passed values.
 * - parameter elements: Elements that are used for matching.
 * - parameter equality: Closure for determining equality of elements that don't conform to `Equatable`.
 * - returns: A `ParameterMatcher`. When the values it keeps are `Sendable`, an overload returns a `SendableMatcher` instead.
 */
public func containsAllValuesOf<K, S: Sequence>(
    _ elements: S,
    where equality: @escaping (S.Element, S.Element) -> Bool
) -> ParameterMatcher<[K: S.Element]> {
    let elements = Array(elements)
    return ParameterMatcher { containsAll($0.values, elements, where: equality) }
}

/**
 * Matcher for dictionaries that checks if the matching dictionary contains all of the passed values.
 * - parameter elements: Elements that are used for matching.
 * - parameter equality: Closure for determining equality of elements that don't conform to `Equatable`.
 * - returns: A `SendableMatcher`, which a `Sendable` mock's stubs accept.
 */
@_disfavoredOverload
public func containsAllValuesOf<K: SendableMetatype, S: Sequence>(
    _ elements: S,
    where equality: @escaping @Sendable (S.Element, S.Element) -> Bool
) -> SendableMatcher<[K: S.Element]> where S.Element: Sendable {
    let elements = Array(elements)
    return SendableMatcher { containsAll($0.values, elements, where: equality) }
}

/**
 * Matcher for dictionaries that checks if the matching dictionary contains all of the passed values.
 * - parameter elements: Variadic elements that are used for matching.
 * - returns: A `ParameterMatcher`. When the values it keeps are `Sendable`, an overload returns a `SendableMatcher` instead.
 */
public func containsAllValuesOf<K, V: Equatable>(values elements: V...) -> ParameterMatcher<[K: V]> {
    containsAllValuesOf(elements)
}

/**
 * Matcher for dictionaries that checks if the matching dictionary contains all of the passed values.
 * - parameter elements: Variadic elements that are used for matching.
 * - returns: A `SendableMatcher`, which a `Sendable` mock's stubs accept.
 */
public func containsAllValuesOf<K: SendableMetatype, V: Equatable & Sendable>(values elements: V...) -> SendableMatcher<[K: V]> {
    containsAllValuesOf(elements)
}

/**
 * Matcher for dictionaries that checks if the matching dictionary contains all of the passed values.
 * - parameter elements: Elements that are used for matching.
 * - returns: A `ParameterMatcher`. When the values it keeps are `Sendable`, an overload returns a `SendableMatcher` instead.
 */
public func containsAllValuesOf<K, S: Sequence>(
    _ elements: S
) -> ParameterMatcher<[K: S.Element]> where S.Element: Equatable {
    let elements = Array(elements)
    return ParameterMatcher { containsAll($0.values, elements, where: ==) }
}

/**
 * Matcher for dictionaries that checks if the matching dictionary contains all of the passed values.
 * - parameter elements: Elements that are used for matching.
 * - returns: A `SendableMatcher`, which a `Sendable` mock's stubs accept.
 */
public func containsAllValuesOf<K: SendableMetatype, S: Sequence>(
    _ elements: S
) -> SendableMatcher<[K: S.Element]> where S.Element: Equatable & Sendable {
    let elements = Array(elements)
    return SendableMatcher { containsAll($0.values, elements, where: ==) }
}

/**
 * Matcher for dictionaries that checks if the matching dictionary contains all of the passed values.
 * - parameter elements: Variadic elements that are used for matching.
 * - returns: A `ParameterMatcher`. When the values it keeps are `Sendable`, an overload returns a `SendableMatcher` instead.
 */
public func containsAllValuesOf<K, V: Hashable>(values elements: V...) -> ParameterMatcher<[K: V]> {
    containsAllValuesOf(elements)
}

/**
 * Matcher for dictionaries that checks if the matching dictionary contains all of the passed values.
 * - parameter elements: Variadic elements that are used for matching.
 * - returns: A `SendableMatcher`, which a `Sendable` mock's stubs accept.
 */
public func containsAllValuesOf<K: SendableMetatype, V: Hashable & Sendable>(values elements: V...) -> SendableMatcher<[K: V]> {
    containsAllValuesOf(elements)
}

/**
 * Matcher for dictionaries that checks if the matching dictionary contains all of the passed values.
 * - parameter elements: Elements that are used for matching.
 * - returns: A `ParameterMatcher`. When the values it keeps are `Sendable`, an overload returns a `SendableMatcher` instead.
 */
public func containsAllValuesOf<K, S: Sequence>(
    _ elements: S
) -> ParameterMatcher<[K: S.Element]> where S.Element: Hashable {
    let counts = elementCounts(elements)
    return ParameterMatcher { containsAll($0.values, counts: counts) }
}

/**
 * Matcher for dictionaries that checks if the matching dictionary contains all of the passed values.
 * - parameter elements: Elements that are used for matching.
 * - returns: A `SendableMatcher`, which a `Sendable` mock's stubs accept.
 */
public func containsAllValuesOf<K: SendableMetatype, S: Sequence>(
    _ elements: S
) -> SendableMatcher<[K: S.Element]> where S.Element: Hashable & Sendable {
    let counts = elementCounts(elements)
    return SendableMatcher { containsAll($0.values, counts: counts) }
}

// MARK: - Contains NONE of the elements as values.
/**
 * Matcher for dictionaries that checks if the matching dictionary contains none of the passed values.
 * - parameter elements: Variadic elements that are used for matching.
 * - parameter equality: Closure for determining equality of elements that don't conform to `Equatable`.
 * - returns: A `ParameterMatcher`. When the values it keeps are `Sendable`, an overload returns a `SendableMatcher` instead.
 */
public func containsNoValuesOf<K, V>(
    values elements: V...,
    where equality: @escaping (V, V) -> Bool
) -> ParameterMatcher<[K: V]> {
    containsNoValuesOf(elements, where: equality)
}

/**
 * Matcher for dictionaries that checks if the matching dictionary contains none of the passed values.
 * - parameter elements: Variadic elements that are used for matching.
 * - parameter equality: Closure for determining equality of elements that don't conform to `Equatable`.
 * - returns: A `SendableMatcher`, which a `Sendable` mock's stubs accept.
 */
@_disfavoredOverload
public func containsNoValuesOf<K: SendableMetatype, V: Sendable>(
    values elements: V...,
    where equality: @escaping @Sendable (V, V) -> Bool
) -> SendableMatcher<[K: V]> {
    containsNoValuesOf(elements, where: equality)
}

/**
 * Matcher for dictionaries that checks if the matching dictionary contains none of the passed values.
 * - parameter elements: Elements that are used for matching.
 * - parameter equality: Closure for determining equality of elements that don't conform to `Equatable`.
 * - returns: A `ParameterMatcher`. When the values it keeps are `Sendable`, an overload returns a `SendableMatcher` instead.
 */
public func containsNoValuesOf<K, S: Sequence>(
    _ elements: S,
    where equality: @escaping (S.Element, S.Element) -> Bool
) -> ParameterMatcher<[K: S.Element]> {
    let elements = Array(elements)
    return ParameterMatcher { containsNone($0.values, elements, where: equality) }
}

/**
 * Matcher for dictionaries that checks if the matching dictionary contains none of the passed values.
 * - parameter elements: Elements that are used for matching.
 * - parameter equality: Closure for determining equality of elements that don't conform to `Equatable`.
 * - returns: A `SendableMatcher`, which a `Sendable` mock's stubs accept.
 */
@_disfavoredOverload
public func containsNoValuesOf<K: SendableMetatype, S: Sequence>(
    _ elements: S,
    where equality: @escaping @Sendable (S.Element, S.Element) -> Bool
) -> SendableMatcher<[K: S.Element]> where S.Element: Sendable {
    let elements = Array(elements)
    return SendableMatcher { containsNone($0.values, elements, where: equality) }
}

/**
 * Matcher for dictionaries that checks if the matching dictionary contains none of the passed values.
 * - parameter elements: Variadic elements that are used for matching.
 * - returns: A `ParameterMatcher`. When the values it keeps are `Sendable`, an overload returns a `SendableMatcher` instead.
 */
public func containsNoValuesOf<K, V: Equatable>(values elements: V...) -> ParameterMatcher<[K: V]> {
    containsNoValuesOf(elements)
}

/**
 * Matcher for dictionaries that checks if the matching dictionary contains none of the passed values.
 * - parameter elements: Variadic elements that are used for matching.
 * - returns: A `SendableMatcher`, which a `Sendable` mock's stubs accept.
 */
public func containsNoValuesOf<K: SendableMetatype, V: Equatable & Sendable>(values elements: V...) -> SendableMatcher<[K: V]> {
    containsNoValuesOf(elements)
}

/**
 * Matcher for dictionaries that checks if the matching dictionary contains none of the passed values.
 * - parameter elements: Elements that are used for matching.
 * - returns: A `ParameterMatcher`. When the values it keeps are `Sendable`, an overload returns a `SendableMatcher` instead.
 */
public func containsNoValuesOf<K, S: Sequence>(
    _ elements: S
) -> ParameterMatcher<[K: S.Element]> where S.Element: Equatable {
    let elements = Array(elements)
    return ParameterMatcher { containsNone($0.values, elements, where: ==) }
}

/**
 * Matcher for dictionaries that checks if the matching dictionary contains none of the passed values.
 * - parameter elements: Elements that are used for matching.
 * - returns: A `SendableMatcher`, which a `Sendable` mock's stubs accept.
 */
public func containsNoValuesOf<K: SendableMetatype, S: Sequence>(
    _ elements: S
) -> SendableMatcher<[K: S.Element]> where S.Element: Equatable & Sendable {
    let elements = Array(elements)
    return SendableMatcher { containsNone($0.values, elements, where: ==) }
}

/**
 * Matcher for dictionaries that checks if the matching dictionary contains none of the passed values.
 * - parameter elements: Variadic elements that are used for matching.
 * - returns: A `ParameterMatcher`. When the values it keeps are `Sendable`, an overload returns a `SendableMatcher` instead.
 */
public func containsNoValuesOf<K, V: Hashable>(values elements: V...) -> ParameterMatcher<[K: V]> {
    containsNoValuesOf(elements)
}

/**
 * Matcher for dictionaries that checks if the matching dictionary contains none of the passed values.
 * - parameter elements: Variadic elements that are used for matching.
 * - returns: A `SendableMatcher`, which a `Sendable` mock's stubs accept.
 */
public func containsNoValuesOf<K: SendableMetatype, V: Hashable & Sendable>(values elements: V...) -> SendableMatcher<[K: V]> {
    containsNoValuesOf(elements)
}

/**
 * Matcher for dictionaries that checks if the matching dictionary contains none of the passed values.
 * - parameter elements: Elements that are used for matching.
 * - returns: A `ParameterMatcher`. When the values it keeps are `Sendable`, an overload returns a `SendableMatcher` instead.
 */
public func containsNoValuesOf<K, S: Sequence>(
    _ elements: S
) -> ParameterMatcher<[K: S.Element]> where S.Element: Hashable {
    let values = Set(elements)
    return ParameterMatcher { values.isDisjoint(with: $0.values) }
}

/**
 * Matcher for dictionaries that checks if the matching dictionary contains none of the passed values.
 * - parameter elements: Elements that are used for matching.
 * - returns: A `SendableMatcher`, which a `Sendable` mock's stubs accept.
 */
public func containsNoValuesOf<K: SendableMetatype, S: Sequence>(
    _ elements: S
) -> SendableMatcher<[K: S.Element]> where S.Element: Hashable & Sendable {
    let values = Set(elements)
    return SendableMatcher { values.isDisjoint(with: $0.values) }
}


// MARK: - Predicates, shared by both kinds of each matcher.
func containsAnyPair<K, V>(_ dictionary: [K: V], _ pairs: [K: V], where equality: (V, V) -> Bool) -> Bool {
    pairs.contains { key, value in
        dictionary[key].map { equality($0, value) } ?? false
    }
}

func containsAllPairs<K, V>(_ dictionary: [K: V], _ pairs: [K: V], where equality: (V, V) -> Bool) -> Bool {
    pairs.allSatisfy { key, value in
        dictionary[key].map { equality($0, value) } ?? false
    }
}

func containsNoPair<K, V>(_ dictionary: [K: V], _ pairs: [K: V], where equality: (V, V) -> Bool) -> Bool {
    !containsAnyPair(dictionary, pairs, where: equality)
}
