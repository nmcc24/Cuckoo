extension Array: _Matchable where Element: _Matchable, Element == Element.MatchedType {
    public typealias MatchedType = [Element]

    public var matcher: ParameterMatcher<[Element]> {
        let matchers = map(\.matcher)
        return ParameterMatcher<[Element]> { other in
            matchers.count == other.count && zip(matchers, other).allSatisfy { $0.matches($1) }
        }
    }
}

extension Array: _SendableMatchable where Element: _SendableMatchable, Element == Element.MatchedType {
    public var sendableMatcher: SendableMatcher<[Element]> {
        let matchers = map(\.sendableMatcher)
        return SendableMatcher<[Element]> { other in
            matchers.count == other.count && zip(matchers, other).allSatisfy { $0.matches($1) }
        }
    }
}

// Each matcher here comes in two kinds, as `equal(to:)` does: a `SendableMatcher` when the elements are `Sendable`,
// and a `ParameterMatcher` otherwise. A matcher that takes a `where:` closure prefers the `ParameterMatcher`, so the
// closure may capture non-`Sendable` state; a `Sendable` mock's stubs pick the `SendableMatcher`.


// MARK: - Contains ANY of the elements.

/**
 * Matcher for sequences of elements that checks if at least one of the passed elements matches the passed sequence.
 * - parameter elements: Variadic elements that are used for matching.
 * - parameter equality: Closure for determining equality of elements that don't conform to `Equatable`.
 * - returns: A matcher: a `SendableMatcher` when the elements are `Sendable`, otherwise a `ParameterMatcher`.
 */
public func containsAnyOf<T, S: Sequence>(
    values elements: T...,
    where equality: @escaping (T, T) -> Bool
) -> ParameterMatcher<S> where T == S.Element {
    containsAnyOf(elements, where: equality)
}

/**
 * Matcher for sequences of elements that checks if at least one of the passed elements matches the passed sequence.
 * - parameter elements: Variadic elements that are used for matching.
 * - parameter equality: Closure for determining equality of elements that don't conform to `Equatable`.
 * - returns: A matcher: a `SendableMatcher` when the elements are `Sendable`, otherwise a `ParameterMatcher`.
 */
@_disfavoredOverload
public func containsAnyOf<T: Sendable, S: Sequence & SendableMetatype>(
    values elements: T...,
    where equality: @escaping @Sendable (T, T) -> Bool
) -> SendableMatcher<S> where T == S.Element {
    containsAnyOf(elements, where: equality)
}

/**
 * Matcher for sequences of elements that checks if at least one of the passed elements matches the passed sequence.
 * - parameter elements: Elements that are used for matching.
 * - parameter equality: Closure for determining equality of elements that don't conform to `Equatable`.
 * - returns: A matcher: a `SendableMatcher` when the elements are `Sendable`, otherwise a `ParameterMatcher`.
 */
public func containsAnyOf<IN: Sequence, OUT: Sequence>(
    _ elements: IN,
    where equality: @escaping (IN.Element, IN.Element) -> Bool
) -> ParameterMatcher<OUT> where IN.Element == OUT.Element {
    let elements = Array(elements)
    return ParameterMatcher { containsAny($0, elements, where: equality) }
}

/**
 * Matcher for sequences of elements that checks if at least one of the passed elements matches the passed sequence.
 * - parameter elements: Elements that are used for matching.
 * - parameter equality: Closure for determining equality of elements that don't conform to `Equatable`.
 * - returns: A matcher: a `SendableMatcher` when the elements are `Sendable`, otherwise a `ParameterMatcher`.
 */
@_disfavoredOverload
public func containsAnyOf<IN: Sequence, OUT: Sequence & SendableMetatype>(
    _ elements: IN,
    where equality: @escaping @Sendable (IN.Element, IN.Element) -> Bool
) -> SendableMatcher<OUT> where IN.Element: Sendable, IN.Element == OUT.Element {
    let elements = Array(elements)
    return SendableMatcher { containsAny($0, elements, where: equality) }
}

/**
 * Matcher for sequences of `Equatable` elements that checks if at least one of the passed elements matches the passed sequence.
 * - parameter elements: Variadic elements that are used for matching.
 * - returns: A matcher: a `SendableMatcher` when the elements are `Sendable`, otherwise a `ParameterMatcher`.
 */
public func containsAnyOf<T: Equatable, S: Sequence>(
    values elements: T...
) -> ParameterMatcher<S> where T == S.Element {
    containsAnyOf(elements)
}

/**
 * Matcher for sequences of `Equatable` elements that checks if at least one of the passed elements matches the passed sequence.
 * - parameter elements: Variadic elements that are used for matching.
 * - returns: A matcher: a `SendableMatcher` when the elements are `Sendable`, otherwise a `ParameterMatcher`.
 */
public func containsAnyOf<T: Equatable & Sendable, S: Sequence & SendableMetatype>(
    values elements: T...
) -> SendableMatcher<S> where T == S.Element {
    containsAnyOf(elements)
}

/**
 * Matcher for sequences of `Equatable` elements that checks if at least one of the passed elements matches the passed sequence.
 * - parameter elements: Elements that are used for matching.
 * - returns: A matcher: a `SendableMatcher` when the elements are `Sendable`, otherwise a `ParameterMatcher`.
 */
public func containsAnyOf<IN: Sequence, OUT: Sequence>(
    _ elements: IN
) -> ParameterMatcher<OUT> where IN.Element: Equatable, IN.Element == OUT.Element {
    let elements = Array(elements)
    return ParameterMatcher { containsAny($0, elements, where: ==) }
}

/**
 * Matcher for sequences of `Equatable` elements that checks if at least one of the passed elements matches the passed sequence.
 * - parameter elements: Elements that are used for matching.
 * - returns: A matcher: a `SendableMatcher` when the elements are `Sendable`, otherwise a `ParameterMatcher`.
 */
public func containsAnyOf<IN: Sequence, OUT: Sequence & SendableMetatype>(
    _ elements: IN
) -> SendableMatcher<OUT> where IN.Element: Equatable & Sendable, IN.Element == OUT.Element {
    let elements = Array(elements)
    return SendableMatcher { containsAny($0, elements, where: ==) }
}

/**
 * Matcher for sequences of `Hashable` elements that checks if at least one of the passed elements matches the passed sequence.
 * - parameter elements: Variadic elements that are used for matching.
 * - returns: A matcher: a `SendableMatcher` when the elements are `Sendable`, otherwise a `ParameterMatcher`.
 */
public func containsAnyOf<T: Hashable, S: Sequence>(
    values elements: T...
) -> ParameterMatcher<S> where T == S.Element {
    containsAnyOf(elements)
}

/**
 * Matcher for sequences of `Hashable` elements that checks if at least one of the passed elements matches the passed sequence.
 * - parameter elements: Variadic elements that are used for matching.
 * - returns: A matcher: a `SendableMatcher` when the elements are `Sendable`, otherwise a `ParameterMatcher`.
 */
public func containsAnyOf<T: Hashable & Sendable, S: Sequence & SendableMetatype>(
    values elements: T...
) -> SendableMatcher<S> where T == S.Element {
    containsAnyOf(elements)
}

/**
 * Matcher for sequences of `Hashable` elements that checks if at least one of the passed elements matches the passed sequence.
 * - parameter elements: Elements that are used for matching.
 * - returns: A matcher: a `SendableMatcher` when the elements are `Sendable`, otherwise a `ParameterMatcher`.
 */
public func containsAnyOf<IN: Sequence, OUT: Sequence>(
    _ elements: IN
) -> ParameterMatcher<OUT> where IN.Element: Hashable, IN.Element == OUT.Element {
    let elements = Set(elements)
    return ParameterMatcher { !Set($0).isDisjoint(with: elements) }
}

/**
 * Matcher for sequences of `Hashable` elements that checks if at least one of the passed elements matches the passed sequence.
 * - parameter elements: Elements that are used for matching.
 * - returns: A matcher: a `SendableMatcher` when the elements are `Sendable`, otherwise a `ParameterMatcher`.
 */
public func containsAnyOf<IN: Sequence, OUT: Sequence & SendableMetatype>(
    _ elements: IN
) -> SendableMatcher<OUT> where IN.Element: Hashable & Sendable, IN.Element == OUT.Element {
    let elements = Set(elements)
    return SendableMatcher { !Set($0).isDisjoint(with: elements) }
}


// MARK: - Contains ALL of the elements.

/**
 * Matcher for sequences of elements that checks if all of the passed elements match the passed sequence.
 * - parameter elements: Variadic elements that are used for matching.
 * - parameter equality: Closure for determining equality of elements that don't conform to `Equatable`.
 * - returns: A matcher: a `SendableMatcher` when the elements are `Sendable`, otherwise a `ParameterMatcher`.
 * - NOTE: An element passed more than once must be in the matched sequence at least as many times.
 */
public func containsAllOf<T, S: Sequence>(
    values elements: T...,
    where equality: @escaping (T, T) -> Bool
) -> ParameterMatcher<S> where T == S.Element {
    containsAllOf(elements, where: equality)
}

/**
 * Matcher for sequences of elements that checks if all of the passed elements match the passed sequence.
 * - parameter elements: Variadic elements that are used for matching.
 * - parameter equality: Closure for determining equality of elements that don't conform to `Equatable`.
 * - returns: A matcher: a `SendableMatcher` when the elements are `Sendable`, otherwise a `ParameterMatcher`.
 * - NOTE: An element passed more than once must be in the matched sequence at least as many times.
 */
@_disfavoredOverload
public func containsAllOf<T: Sendable, S: Sequence & SendableMetatype>(
    values elements: T...,
    where equality: @escaping @Sendable (T, T) -> Bool
) -> SendableMatcher<S> where T == S.Element {
    containsAllOf(elements, where: equality)
}

/**
 * Matcher for sequences of elements that checks if all of the passed elements match the passed sequence.
 * - parameter elements: Elements that are used for matching.
 * - parameter equality: Closure for determining equality of elements that don't conform to `Equatable`.
 * - returns: A matcher: a `SendableMatcher` when the elements are `Sendable`, otherwise a `ParameterMatcher`.
 * - NOTE: An element passed more than once must be in the matched sequence at least as many times.
 */
public func containsAllOf<IN: Sequence, OUT: Sequence>(
    _ elements: IN,
    where equality: @escaping (IN.Element, IN.Element) -> Bool
) -> ParameterMatcher<OUT> where IN.Element == OUT.Element {
    let elements = Array(elements)
    return ParameterMatcher { containsAll($0, elements, where: equality) }
}

/**
 * Matcher for sequences of elements that checks if all of the passed elements match the passed sequence.
 * - parameter elements: Elements that are used for matching.
 * - parameter equality: Closure for determining equality of elements that don't conform to `Equatable`.
 * - returns: A matcher: a `SendableMatcher` when the elements are `Sendable`, otherwise a `ParameterMatcher`.
 * - NOTE: An element passed more than once must be in the matched sequence at least as many times.
 */
@_disfavoredOverload
public func containsAllOf<IN: Sequence, OUT: Sequence & SendableMetatype>(
    _ elements: IN,
    where equality: @escaping @Sendable (IN.Element, IN.Element) -> Bool
) -> SendableMatcher<OUT> where IN.Element: Sendable, IN.Element == OUT.Element {
    let elements = Array(elements)
    return SendableMatcher { containsAll($0, elements, where: equality) }
}

/**
 * Matcher for sequences of `Equatable` elements that checks if all of the passed elements match the passed sequence.
 * - parameter elements: Variadic elements that are used for matching.
 * - returns: A matcher: a `SendableMatcher` when the elements are `Sendable`, otherwise a `ParameterMatcher`.
 * - NOTE: An element passed more than once must be in the matched sequence at least as many times.
 */
public func containsAllOf<T: Equatable, S: Sequence>(
    values elements: T...
) -> ParameterMatcher<S> where T == S.Element {
    containsAllOf(elements)
}

/**
 * Matcher for sequences of `Equatable` elements that checks if all of the passed elements match the passed sequence.
 * - parameter elements: Variadic elements that are used for matching.
 * - returns: A matcher: a `SendableMatcher` when the elements are `Sendable`, otherwise a `ParameterMatcher`.
 * - NOTE: An element passed more than once must be in the matched sequence at least as many times.
 */
public func containsAllOf<T: Equatable & Sendable, S: Sequence & SendableMetatype>(
    values elements: T...
) -> SendableMatcher<S> where T == S.Element {
    containsAllOf(elements)
}

/**
 * Matcher for sequences of `Equatable` elements that checks if all of the passed elements match the passed sequence.
 * - parameter elements: Elements that are used for matching.
 * - returns: A matcher: a `SendableMatcher` when the elements are `Sendable`, otherwise a `ParameterMatcher`.
 * - NOTE: An element passed more than once must be in the matched sequence at least as many times.
 */
public func containsAllOf<IN: Sequence, OUT: Sequence>(
    _ elements: IN
) -> ParameterMatcher<OUT> where IN.Element: Equatable, IN.Element == OUT.Element {
    let elements = Array(elements)
    return ParameterMatcher { containsAll($0, elements, where: ==) }
}

/**
 * Matcher for sequences of `Equatable` elements that checks if all of the passed elements match the passed sequence.
 * - parameter elements: Elements that are used for matching.
 * - returns: A matcher: a `SendableMatcher` when the elements are `Sendable`, otherwise a `ParameterMatcher`.
 * - NOTE: An element passed more than once must be in the matched sequence at least as many times.
 */
public func containsAllOf<IN: Sequence, OUT: Sequence & SendableMetatype>(
    _ elements: IN
) -> SendableMatcher<OUT> where IN.Element: Equatable & Sendable, IN.Element == OUT.Element {
    let elements = Array(elements)
    return SendableMatcher { containsAll($0, elements, where: ==) }
}

/**
 * Matcher for sequences of `Hashable` elements that checks if all of the passed elements match the passed sequence.
 * - parameter elements: Variadic elements that are used for matching.
 * - returns: A matcher: a `SendableMatcher` when the elements are `Sendable`, otherwise a `ParameterMatcher`.
 * - NOTE: An element passed more than once must be in the matched sequence at least as many times.
 */
public func containsAllOf<T: Hashable>(values elements: T...) -> ParameterMatcher<[T]> {
    containsAllOf(elements)
}

/**
 * Matcher for sequences of `Hashable` elements that checks if all of the passed elements match the passed sequence.
 * - parameter elements: Variadic elements that are used for matching.
 * - returns: A matcher: a `SendableMatcher` when the elements are `Sendable`, otherwise a `ParameterMatcher`.
 * - NOTE: An element passed more than once must be in the matched sequence at least as many times.
 */
public func containsAllOf<T: Hashable & Sendable>(values elements: T...) -> SendableMatcher<[T]> {
    containsAllOf(elements)
}

/**
 * Matcher for sequences of `Hashable` elements that checks if all of the passed elements match the passed sequence.
 * - parameter elements: Elements that are used for matching.
 * - returns: A matcher: a `SendableMatcher` when the elements are `Sendable`, otherwise a `ParameterMatcher`.
 * - NOTE: An element passed more than once must be in the matched sequence at least as many times.
 */
public func containsAllOf<IN: Sequence, OUT: Sequence>(
    _ elements: IN
) -> ParameterMatcher<OUT> where IN.Element: Hashable, IN.Element == OUT.Element {
    let counts = elementCounts(elements)
    return ParameterMatcher { containsAll($0, counts: counts) }
}

/**
 * Matcher for sequences of `Hashable` elements that checks if all of the passed elements match the passed sequence.
 * - parameter elements: Elements that are used for matching.
 * - returns: A matcher: a `SendableMatcher` when the elements are `Sendable`, otherwise a `ParameterMatcher`.
 * - NOTE: An element passed more than once must be in the matched sequence at least as many times.
 */
public func containsAllOf<IN: Sequence, OUT: Sequence & SendableMetatype>(
    _ elements: IN
) -> SendableMatcher<OUT> where IN.Element: Hashable & Sendable, IN.Element == OUT.Element {
    let counts = elementCounts(elements)
    return SendableMatcher { containsAll($0, counts: counts) }
}

/**
 * Matcher for `Set`s of `Hashable` elements that checks if all of the passed elements match the passed `Set`.
 * - parameter elements: Elements that are used for matching.
 * - returns: A matcher: a `SendableMatcher` when the elements are `Sendable`, otherwise a `ParameterMatcher`.
 */
public func containsAllOf<IN: Sequence, OUT: Sequence>(
    _ elements: IN
) -> ParameterMatcher<OUT> where IN.Element: Hashable, IN.Element == OUT.Element, IN: SetAlgebra {
    let elements = Set(elements)
    return ParameterMatcher { Set($0).isSuperset(of: elements) }
}

/**
 * Matcher for `Set`s of `Hashable` elements that checks if all of the passed elements match the passed `Set`.
 * - parameter elements: Elements that are used for matching.
 * - returns: A matcher: a `SendableMatcher` when the elements are `Sendable`, otherwise a `ParameterMatcher`.
 */
public func containsAllOf<IN: Sequence, OUT: Sequence & SendableMetatype>(
    _ elements: IN
) -> SendableMatcher<OUT> where IN.Element: Hashable & Sendable, IN.Element == OUT.Element, IN: SetAlgebra {
    let elements = Set(elements)
    return SendableMatcher { Set($0).isSuperset(of: elements) }
}


// MARK: - Contains NONE of the elements.

/**
 * Matcher for sequences of elements that checks if none of the passed elements match the passed sequence.
 * - parameter elements: Variadic elements that are used for matching.
 * - parameter equality: Closure for determining equality of elements that don't conform to `Equatable`.
 * - returns: A matcher: a `SendableMatcher` when the elements are `Sendable`, otherwise a `ParameterMatcher`.
 */
public func containsNoneOf<T, S: Sequence>(
    values elements: T...,
    where equality: @escaping (T, T) -> Bool
) -> ParameterMatcher<S> where T == S.Element {
    containsNoneOf(elements, where: equality)
}

/**
 * Matcher for sequences of elements that checks if none of the passed elements match the passed sequence.
 * - parameter elements: Variadic elements that are used for matching.
 * - parameter equality: Closure for determining equality of elements that don't conform to `Equatable`.
 * - returns: A matcher: a `SendableMatcher` when the elements are `Sendable`, otherwise a `ParameterMatcher`.
 */
@_disfavoredOverload
public func containsNoneOf<T: Sendable, S: Sequence & SendableMetatype>(
    values elements: T...,
    where equality: @escaping @Sendable (T, T) -> Bool
) -> SendableMatcher<S> where T == S.Element {
    containsNoneOf(elements, where: equality)
}

/**
 * Matcher for sequences of elements that checks if none of the passed elements match the passed sequence.
 * - parameter elements: Elements that are used for matching.
 * - parameter equality: Closure for determining equality of elements that don't conform to `Equatable`.
 * - returns: A matcher: a `SendableMatcher` when the elements are `Sendable`, otherwise a `ParameterMatcher`.
 */
public func containsNoneOf<IN: Sequence, OUT: Sequence>(
    _ elements: IN,
    where equality: @escaping (IN.Element, IN.Element) -> Bool
) -> ParameterMatcher<OUT> where IN.Element == OUT.Element {
    let elements = Array(elements)
    return ParameterMatcher { containsNone($0, elements, where: equality) }
}

/**
 * Matcher for sequences of elements that checks if none of the passed elements match the passed sequence.
 * - parameter elements: Elements that are used for matching.
 * - parameter equality: Closure for determining equality of elements that don't conform to `Equatable`.
 * - returns: A matcher: a `SendableMatcher` when the elements are `Sendable`, otherwise a `ParameterMatcher`.
 */
@_disfavoredOverload
public func containsNoneOf<IN: Sequence, OUT: Sequence & SendableMetatype>(
    _ elements: IN,
    where equality: @escaping @Sendable (IN.Element, IN.Element) -> Bool
) -> SendableMatcher<OUT> where IN.Element: Sendable, IN.Element == OUT.Element {
    let elements = Array(elements)
    return SendableMatcher { containsNone($0, elements, where: equality) }
}

/**
 * Matcher for sequences of `Equatable` elements that checks if none of the passed elements match the passed sequence.
 * - parameter elements: Variadic elements that are used for matching.
 * - returns: A matcher: a `SendableMatcher` when the elements are `Sendable`, otherwise a `ParameterMatcher`.
 */
public func containsNoneOf<T: Equatable, S: Sequence>(
    values elements: T...
) -> ParameterMatcher<S> where T == S.Element {
    containsNoneOf(elements)
}

/**
 * Matcher for sequences of `Equatable` elements that checks if none of the passed elements match the passed sequence.
 * - parameter elements: Variadic elements that are used for matching.
 * - returns: A matcher: a `SendableMatcher` when the elements are `Sendable`, otherwise a `ParameterMatcher`.
 */
public func containsNoneOf<T: Equatable & Sendable, S: Sequence & SendableMetatype>(
    values elements: T...
) -> SendableMatcher<S> where T == S.Element {
    containsNoneOf(elements)
}

/**
 * Matcher for sequences of `Equatable` elements that checks if none of the passed elements match the passed sequence.
 * - parameter elements: Elements that are used for matching.
 * - returns: A matcher: a `SendableMatcher` when the elements are `Sendable`, otherwise a `ParameterMatcher`.
 */
public func containsNoneOf<IN: Sequence, OUT: Sequence>(
    _ elements: IN
) -> ParameterMatcher<OUT> where IN.Element: Equatable, IN.Element == OUT.Element {
    let elements = Array(elements)
    return ParameterMatcher { containsNone($0, elements, where: ==) }
}

/**
 * Matcher for sequences of `Equatable` elements that checks if none of the passed elements match the passed sequence.
 * - parameter elements: Elements that are used for matching.
 * - returns: A matcher: a `SendableMatcher` when the elements are `Sendable`, otherwise a `ParameterMatcher`.
 */
public func containsNoneOf<IN: Sequence, OUT: Sequence & SendableMetatype>(
    _ elements: IN
) -> SendableMatcher<OUT> where IN.Element: Equatable & Sendable, IN.Element == OUT.Element {
    let elements = Array(elements)
    return SendableMatcher { containsNone($0, elements, where: ==) }
}

/**
 * Matcher for sequences of `Hashable` elements that checks if none of the passed elements match the passed sequence.
 * - parameter elements: Variadic elements that are used for matching.
 * - returns: A matcher: a `SendableMatcher` when the elements are `Sendable`, otherwise a `ParameterMatcher`.
 */
public func containsNoneOf<T: Hashable, S: Sequence>(
    values elements: T...
) -> ParameterMatcher<S> where T == S.Element {
    containsNoneOf(elements)
}

/**
 * Matcher for sequences of `Hashable` elements that checks if none of the passed elements match the passed sequence.
 * - parameter elements: Variadic elements that are used for matching.
 * - returns: A matcher: a `SendableMatcher` when the elements are `Sendable`, otherwise a `ParameterMatcher`.
 */
public func containsNoneOf<T: Hashable & Sendable, S: Sequence & SendableMetatype>(
    values elements: T...
) -> SendableMatcher<S> where T == S.Element {
    containsNoneOf(elements)
}

/**
 * Matcher for sequences of `Hashable` elements that checks if none of the passed elements match the passed sequence.
 * - parameter elements: Elements that are used for matching.
 * - returns: A matcher: a `SendableMatcher` when the elements are `Sendable`, otherwise a `ParameterMatcher`.
 */
public func containsNoneOf<IN: Sequence, OUT: Sequence>(
    _ elements: IN
) -> ParameterMatcher<OUT> where IN.Element: Hashable, IN.Element == OUT.Element {
    let elements = Set(elements)
    return ParameterMatcher { Set($0).isDisjoint(with: elements) }
}

/**
 * Matcher for sequences of `Hashable` elements that checks if none of the passed elements match the passed sequence.
 * - parameter elements: Elements that are used for matching.
 * - returns: A matcher: a `SendableMatcher` when the elements are `Sendable`, otherwise a `ParameterMatcher`.
 */
public func containsNoneOf<IN: Sequence, OUT: Sequence & SendableMetatype>(
    _ elements: IN
) -> SendableMatcher<OUT> where IN.Element: Hashable & Sendable, IN.Element == OUT.Element {
    let elements = Set(elements)
    return SendableMatcher { Set($0).isDisjoint(with: elements) }
}


// MARK: - Has length N (exact, at least, at most).
/**
 * Matcher for collections of elements that checks if the collection is exactly N elements long.
 * - parameter requiredExactLength: Required length of the matching collection.
 * - returns: SendableMatcher object.
 */
public func hasLength<C: Collection & SendableMetatype>(exactly requiredExactLength: Int) -> SendableMatcher<C> {
    SendableMatcher { collection in
        collection.count == requiredExactLength
    }
}

/**
 * Matcher for collections of elements that checks if the collection is at least N elements long with the option to include the number itself (default).
 * - parameter requiredMinimumLength: Required minimum length of the matching collection.
 * - parameter inclusive: Whether the minimum length itself should be included.
 * - returns: SendableMatcher object.
 */
public func hasLength<C: Collection & SendableMetatype>(
    atLeast requiredMinimumLength: Int,
    inclusive: Bool = true
) -> SendableMatcher<C> {
    SendableMatcher { collection in
        collection.count > requiredMinimumLength || (inclusive && collection.count == requiredMinimumLength)
    }
}

/**
 * Matcher for collections of elements that checks if the collection is at most N elements long with the option to include the number itself (default).
 * - parameter requiredMaximumLength: Required maximum length of the matching collection.
 * - parameter inclusive: Whether the maximum length itself should be included.
 * - returns: SendableMatcher object.
 */
public func hasLength<C: Collection & SendableMetatype>(
    atMost requiredMaximumLength: Int,
    inclusive: Bool = true
) -> SendableMatcher<C> {
    SendableMatcher { collection in
        collection.count < requiredMaximumLength || (inclusive && collection.count == requiredMaximumLength)
    }
}

/**
 * Matcher for collections of elements that checks if the collection's length is in a range, such as `1..<3`, `1...3` or `2...`.
 * - parameter requiredLengthRange: The lengths that match, with the range's own bounds: `1..<3` matches 1 and 2.
 * - returns: SendableMatcher object.
 */
public func hasLength<C: Collection & SendableMetatype>(
    inRange requiredLengthRange: some RangeExpression<Int> & Sendable
) -> SendableMatcher<C> {
    SendableMatcher { collection in
        requiredLengthRange.contains(collection.count)
    }
}

/**
 * Matcher for collections of elements that checks if the collection is between N and M elements long, both bounds
 * included or both excluded.
 * - parameter requiredLengthRange: Required length range of the matching collection. Its upper bound counts as a
 *   bound, despite the half-open range: `1..<3` with `inclusive: true` matches 3.
 * - parameter inclusive: Whether the length range bounds should be included.
 * - returns: SendableMatcher object.
 */
@available(*, deprecated, message: "Use hasLength(inRange:) with the range you mean, such as 1...3 or 2..<4.")
public func hasLength<C: Collection & SendableMetatype>(
    inRange requiredLengthRange: CountableRange<Int>,
    inclusive: Bool
) -> SendableMatcher<C> {
    hasLength(atLeast: requiredLengthRange.lowerBound, inclusive: inclusive)
        .and(hasLength(atMost: requiredLengthRange.upperBound, inclusive: inclusive))
}


// MARK: - Predicates, shared by both kinds of each matcher.
func containsAny<S: Sequence>(_ sequence: S, _ elements: [S.Element], where equality: (S.Element, S.Element) -> Bool) -> Bool {
    elements.contains { element in
        sequence.contains { equality($0, element) }
    }
}

func containsNone<S: Sequence>(_ sequence: S, _ elements: [S.Element], where equality: (S.Element, S.Element) -> Bool) -> Bool {
    !containsAny(sequence, elements, where: equality)
}

func containsAll<S: Sequence>(_ sequence: S, _ elements: [S.Element], where equality: (S.Element, S.Element) -> Bool) -> Bool {
    var matchedSequence = sequence.map { (element: $0, matched: false) }
    for element in elements {
        guard let matchedIndex = matchedSequence.firstIndex(where: { !$0.matched && equality($0.element, element) }) else {
            return false
        }
        matchedSequence[matchedIndex].matched = true
    }
    return true
}

func elementCounts<S: Sequence>(_ elements: S) -> [S.Element: Int] where S.Element: Hashable {
    elements.reduce(into: [:]) { counts, element in
        counts[element, default: 0] += 1
    }
}

func containsAll<S: Sequence>(_ sequence: S, counts: [S.Element: Int]) -> Bool where S.Element: Hashable {
    let sequenceCounts = elementCounts(sequence)
    return counts.allSatisfy { element, count in
        sequenceCounts[element].map { $0 >= count } ?? false
    }
}
