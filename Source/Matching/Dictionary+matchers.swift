extension Dictionary: Matchable where Value: Matchable, Value == Value.MatchedType {
    public typealias MatchedType = [Key: Value]

    public var matcher: ParameterMatcher<[Key: Value]> {
        // A conditional conformance can't require `Sendable` (or `SendableMetatype`) keys, so the comparison is kept
        // unchecked: it only hashes and compares the keys, which a dictionary already requires to give the same answer
        // whatever task asks.
        let matchers = mapValues(\.matcher)
        return ParameterMatcher<[Key: Value]>(uncheckedSendable: { other in
            guard matchers.count == other.count else { return false }
            return matchers.allSatisfy {
                guard let foundElement = other[$0.key] else { return false }
                return $0.value.matches(foundElement)
            }
        })
    }
}

// MARK: PAIR MATCHING
// MARK: - Contains ANY of the elements as key-value pairs.
/**
 * Matcher for dictionaries that checks if the matching dictionary contains any of the key-value pairs from the passed dictionary.
 * - parameter inputDictionary: Dictionary that is used for matching.
 * - returns: ParameterMatcher object.
 */
public func containsAnyOf<K: Sendable, V: Equatable & Sendable>(_ inputDictionary: [K: V]) -> ParameterMatcher<[K: V]> {
    containsAnyOf(inputDictionary, where: ==)
}
/**
 * Matcher for dictionaries that checks if the matching dictionary contains any of the key-value pairs from the passed dictionary.
 * - parameter inputDictionary: Dictionary that is used for matching.
 * - parameter equality: Closure for determining equality of elements that don't conform to `Equatable`.
 * - returns: ParameterMatcher object.
 */
public func containsAnyOf<K: Sendable, V: Sendable>(
    _ inputDictionary: [K: V],
    where equality: @escaping @Sendable (V, V) -> Bool
) -> ParameterMatcher<[K: V]> {
    ParameterMatcher { dictionary in
        inputDictionary.contains { key, value in
            dictionary[key].map { equality($0, value) } ?? false
        }
    }
}

// MARK: - Contains ALL of the elements as key-value pairs.
/**
 * Matcher for dictionaries that checks if the matching dictionary contains all of the key-value pairs from the passed dictionary.
 * - parameter inputDictionary: Dictionary that is used for matching.
 * - returns: ParameterMatcher object.
 */
public func containsAllOf<K: Sendable, V: Equatable & Sendable>(_ inputDictionary: [K: V]) -> ParameterMatcher<[K: V]> {
    containsAllOf(inputDictionary, where: ==)
}
/**
 * Matcher for dictionaries that checks if the matching dictionary contains all of the key-value pairs from the passed dictionary.
 * - parameter inputDictionary: Dictionary that is used for matching.
 * - parameter equality: Closure for determining equality of elements that don't conform to `Equatable`.
 * - returns: ParameterMatcher object.
 */
public func containsAllOf<K: Sendable, V: Sendable>(_ inputDictionary: [K: V], where equality: @escaping @Sendable (V, V) -> Bool) -> ParameterMatcher<[K: V]> {
    ParameterMatcher { dictionary in
        inputDictionary.allSatisfy { key, value in
            dictionary[key].map { equality($0, value) } ?? false
        }
    }
}

// MARK: - Contains NONE of the elements as key-value pairs.
/**
 * Matcher for dictionaries that checks if the matching dictionary contains none of the key-value pairs from the passed dictionary.
 * - parameter inputDictionary: Dictionary that is used for matching.
 * - returns: ParameterMatcher object.
 */
public func containsNoneOf<K: Sendable, V: Equatable & Sendable>(_ inputDictionary: [K: V]) -> ParameterMatcher<[K: V]> {
    containsNoneOf(inputDictionary, where: ==)
}
/**
 * Matcher for dictionaries that checks if the matching dictionary contains none of the key-value pairs from the passed dictionary.
 * - parameter inputDictionary: Dictionary that is used for matching.
 * - parameter equality: Closure for determining equality of elements that don't conform to `Equatable`.
 * - returns: ParameterMatcher object.
 */
public func containsNoneOf<K: Sendable, V: Sendable>(
    _ inputDictionary: [K: V],
    where equality: @escaping @Sendable (V, V) -> Bool
) -> ParameterMatcher<[K: V]> {
    not(containsAnyOf(inputDictionary, where: equality))
}


// MARK: KEYS MATCHING
// MARK: - Contains ANY of the elements as keys.
/**
 * Matcher for dictionaries that checks if the matching dictionary contains any of the passed keys.
 * - parameter elements: Variadic keys that are used for matching.
 * - returns: ParameterMatcher object.
 */
public func containsAnyKeysOf<K: Hashable & Sendable, V: SendableMetatype>(values elements: K...) -> ParameterMatcher<[K: V]> {
    containsAnyKeysOf(elements)
}
/**
 * Matcher for dictionaries that checks if the matching dictionary contains any of the passed keys.
 * - parameter elements: Keys that are used for matching.
 * - returns: ParameterMatcher object.
 */
public func containsAnyKeysOf<S: Sequence, V: SendableMetatype>(_ elements: S) -> ParameterMatcher<[S.Element: V]> where S.Element: Sendable {
    let matcher: ParameterMatcher<[S.Element: V].Keys> = containsAnyOf(elements)
    return ParameterMatcher { dictionary in
        matcher.matches(dictionary.keys)
    }
}

// MARK: - Contains ALL of the elements as keys.
/**
 * Matcher for dictionaries that checks if the matching dictionary contains all of the passed keys.
 * - parameter elements: Variadic keys that are used for matching
 * - returns: ParameterMatcher object.
 */
public func containsAllKeysOf<K: Hashable & Sendable, V: SendableMetatype>(values elements: K...) -> ParameterMatcher<[K: V]> {
    containsAllKeysOf(elements)
}
/**
 * Matcher for dictionaries that checks if the matching dictionary contains all of the passed keys.
 * - parameter elements: Keys that are used for matching.
 * - returns: ParameterMatcher object.
 */
public func containsAllKeysOf<S: Sequence, V: SendableMetatype>(_ elements: S) -> ParameterMatcher<[S.Element: V]> where S.Element: Sendable {
    let matcher: ParameterMatcher<[S.Element: V].Keys> = containsAllOf(elements)
    return ParameterMatcher { dictionary in
        matcher.matches(dictionary.keys)
    }
}

// MARK: - Contains NONE of the elements as keys.
/**
 * Matcher for dictionaries that checks if the matching dictionary contains none of the passed keys.
 * - parameter elements: Variadic keys that are used for matching
 * - returns: ParameterMatcher object.
 */
public func containsNoKeysOf<K: Hashable & Sendable, V: SendableMetatype>(values elements: K...) -> ParameterMatcher<[K: V]> {
    containsNoKeysOf(elements)
}
/**
 * Matcher for dictionaries that checks if the matching dictionary contains none of the passed keys.
 * - parameter elements: Keys that are used for matching.
 * - returns: ParameterMatcher object.
 */
public func containsNoKeysOf<S: Sequence, V: SendableMetatype>(_ elements: S) -> ParameterMatcher<[S.Element: V]> where S.Element: Sendable {
    not(containsAnyKeysOf(elements))
}


// MARK: VALUES MATCHING
// MARK: - Contains ANY of the elements as values.
/**
 * Matcher for dictionaries that checks if the matching dictionary contains any of the passed values.
 * - parameter elements: Variadic values that are used for matching.
 * - parameter equality: Closure for determining equality of elements that don't conform to `Equatable`.
 * - returns: ParameterMatcher object.
 */
public func containsAnyValuesOf<K: Hashable & SendableMetatype, V: Sendable>(
    values elements: V...,
    where equality: @escaping @Sendable (V, V) -> Bool
) -> ParameterMatcher<[K: V]> {
    containsAnyValuesOf(elements, where: equality)
}
/**
 * Matcher for dictionaries that checks if the matching dictionary contains any of the passed values.
 * - parameter elements: Values that are used for matching.
 * - parameter equality: Closure for determining equality of elements that don't conform to `Equatable`.
 * - returns: ParameterMatcher object.
 */
public func containsAnyValuesOf<K: Hashable & SendableMetatype, S: Sequence>(
    _ elements: S,
    where equality: @escaping @Sendable (S.Element, S.Element) -> Bool
) -> ParameterMatcher<[K: S.Element]> where S.Element: Sendable {
    let matcher: ParameterMatcher<[K: S.Element].Values> = containsAnyOf(elements, where: equality)
    return ParameterMatcher { dictionary in
        matcher.matches(dictionary.values)
    }
}

/**
 * Matcher for dictionaries that checks if the matching dictionary contains any of the passed values.
 * - parameter elements: Variadic keys that are used for matching
 * - returns: ParameterMatcher object.
 */
public func containsAnyValuesOf<K: Hashable & SendableMetatype, V: Equatable & Sendable>(values elements: V...) -> ParameterMatcher<[K: V]> {
    return containsAnyValuesOf(elements)
}
/**
 * Matcher for dictionaries that checks if the matching dictionary contains any of the passed values.
 * - parameter elements: Keys that are used for matching.
 * - returns: ParameterMatcher object.
 */
public func containsAnyValuesOf<K: Hashable & SendableMetatype, S: Sequence>(
    _ elements: S
) -> ParameterMatcher<[K: S.Element]> where S.Element: Equatable & Sendable {
    containsAnyValuesOf(elements, where: ==)
}


/**
 * Matcher for dictionaries that checks if the matching dictionary contains any of the passed values.
 * - parameter elements: Variadic values that are used for matching
 * - returns: ParameterMatcher object.
 */
public func containsAnyValuesOf<K: Hashable & SendableMetatype, V: Hashable & Sendable>(values elements: V...) -> ParameterMatcher<[K: V]> {
    containsAnyValuesOf(elements)
}
/**
 * Matcher for dictionaries that checks if the matching dictionary contains none of the passed values.
 * - parameter elements: Values that are used for matching.
 * - returns: ParameterMatcher object.
 */
public func containsAnyValuesOf<K: Hashable & SendableMetatype, S: Sequence>(
    _ elements: S
) -> ParameterMatcher<[K: S.Element]> where S.Element: Hashable & Sendable {
    let matcher: ParameterMatcher<[K: S.Element].Values> = containsAnyOf(elements)
    return ParameterMatcher { dictionary in
        matcher.matches(dictionary.values)
    }
}

// MARK: - Contains ALL of the elements as values.
/**
 * Matcher for dictionaries that checks if the matching dictionary contains all of the passed values.
 * - parameter elements: Variadic values that are used for matching.
 * - parameter equality: Closure for determining equality of elements that don't conform to `Equatable`.
 * - returns: ParameterMatcher object.
 */
public func containsAllValuesOf<K: Hashable & SendableMetatype, V: Sendable>(
    values elements: V...,
    where equality: @escaping @Sendable (V, V) -> Bool
) -> ParameterMatcher<[K: V]> {
    containsAllValuesOf(elements, where: equality)
}
/**
 * Matcher for dictionaries that checks if the matching dictionary contains all of the passed values.
 * - parameter elements: Values that are used for matching.
 * - parameter equality: Closure for determining equality of elements that don't conform to `Equatable`.
 * - returns: ParameterMatcher object.
 */
public func containsAllValuesOf<K: Hashable & SendableMetatype, S: Sequence>(
    _ elements: S,
    where equality: @escaping @Sendable (S.Element, S.Element) -> Bool
) -> ParameterMatcher<[K: S.Element]> where S.Element: Sendable {
    let matcher: ParameterMatcher<[K: S.Element].Values> = containsAllOf(elements, where: equality)
    return ParameterMatcher { dictionary in
        matcher.matches(dictionary.values)
    }
}

/**
 * Matcher for dictionaries that checks if the matching dictionary contains all of the passed values.
 * - parameter elements: Variadic values that are used for matching.
 * - returns: ParameterMatcher object.
 */
public func containsAllValuesOf<K: Hashable & SendableMetatype, V: Equatable & Sendable>(values elements: V...) -> ParameterMatcher<[K: V]> {
    containsAllValuesOf(elements)
}
/**
 * Matcher for dictionaries that checks if the matching dictionary contains all of the passed values.
 * - parameter elements: Values that are used for matching.
 * - returns: ParameterMatcher object.
 */
public func containsAllValuesOf<K: Hashable & SendableMetatype, S: Sequence>(
    _ elements: S
) -> ParameterMatcher<[K: S.Element]> where S.Element: Equatable & Sendable {
    containsAllValuesOf(elements, where: ==)
}

/**
 * Matcher for dictionaries that checks if the matching dictionary contains all of the passed values.
 * - parameter elements: Variadic values that are used for matching.
 * - returns: ParameterMatcher object.
 */
public func containsAllValuesOf<K: Hashable & SendableMetatype, V: Hashable & Sendable>(values elements: V...) -> ParameterMatcher<[K: V]> {
    containsAllValuesOf(elements)
}
/**
 * Matcher for dictionaries that checks if the matching dictionary contains all of the passed values.
 * - parameter elements: Values that are used for matching.
 * - returns: ParameterMatcher object.
 */
public func containsAllValuesOf<K: Hashable & SendableMetatype, S: Sequence>(
    _ elements: S
) -> ParameterMatcher<[K: S.Element]> where S.Element: Hashable & Sendable {
    let matcher: ParameterMatcher<[K: S.Element].Values> = containsAllOf(elements)
    return ParameterMatcher { dictionary in
        matcher.matches(dictionary.values)
    }
}

// MARK: - Contains NONE of the elements as values.
/**
 * Matcher for dictionaries that checks if the matching dictionary contains none of the passed values.
 * - parameter elements: Variadic values that are used for matching.
 * - parameter equality: Closure for determining equality of elements that don't conform to `Equatable`.
 * - returns: ParameterMatcher object.
 */
public func containsNoValuesOf<K: Hashable & SendableMetatype, V: Sendable>(
    values elements: V...,
    where equality: @escaping @Sendable (V, V) -> Bool
) -> ParameterMatcher<[K: V]> {
    containsNoValuesOf(elements, where: equality)
}
/**
 * Matcher for dictionaries that checks if the matching dictionary contains none of the passed values.
 * - parameter elements: Values that are used for matching.
 * - parameter equality: Closure for determining equality of elements that don't conform to `Equatable`.
 * - returns: ParameterMatcher object.
 */
public func containsNoValuesOf<K: Hashable & SendableMetatype, S: Sequence>(
    _ elements: S,
    where equality: @escaping @Sendable (S.Element, S.Element) -> Bool
) -> ParameterMatcher<[K: S.Element]> where S.Element: Sendable {
    not(containsAnyValuesOf(elements, where: equality))
}

/**
 * Matcher for dictionaries that checks if the matching dictionary contains none of the passed values.
 * - parameter elements: Variadic values that are used for matching.
 * - returns: ParameterMatcher object.
 */
public func containsNoValuesOf<K: Hashable & SendableMetatype, V: Equatable & Sendable>(values elements: V...) -> ParameterMatcher<[K: V]> {
    containsNoValuesOf(elements)
}
/**
 * Matcher for dictionaries that checks if the matching dictionary contains none of the passed values.
 * - parameter elements: Values that are used for matching.
 * - returns: ParameterMatcher object.
 */
public func containsNoValuesOf<K: Hashable & SendableMetatype, S: Sequence>(
    _ elements: S
) -> ParameterMatcher<[K: S.Element]> where S.Element: Equatable & Sendable {
    containsNoValuesOf(elements, where: ==)
}

/**
 * Matcher for dictionaries that checks if the matching dictionary contains none of the passed values.
 * - parameter elements: Variadic values that are used for matching.
 * - returns: ParameterMatcher object.
 */
public func containsNoValuesOf<K: Hashable & SendableMetatype, V: Hashable & Sendable>(values elements: V...) -> ParameterMatcher<[K: V]> {
    containsNoValuesOf(elements)
}
/**
 * Matcher for dictionaries that checks if the matching dictionary contains none of the passed values.
 * - parameter elements: Values that are used for matching.
 * - returns: ParameterMatcher object.
 */
public func containsNoValuesOf<K: Hashable & SendableMetatype, S: Sequence>(
    _ elements: S
) -> ParameterMatcher<[K: S.Element]> where S.Element: Hashable & Sendable {
    not(containsAnyValuesOf(elements))
}
