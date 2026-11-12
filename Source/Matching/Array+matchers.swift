extension Array: Matchable where Element: Matchable, Element == Element.MatchedType {
    public typealias MatchedType = [Element]

    public var matcher: ParameterMatcher<[Element]> {
        ParameterMatcher<[Element]> { other in
            guard self.count == other.count else { return false }
            return zip(self, other).allSatisfy { $0.matcher.matches($1) }
        }
    }
}


// MARK: - Contains ANY of the elements.
/**
 * Matcher for sequences of elements that checks if at least one of the passed elements matches the passed sequence.
 * - parameter elements: Variadic elements that are used for matching.
 * - parameter equality: Closure for determining equality of elements that don't conform to `Equatable`.
 * - returns: ParameterMatcher object.
 */
public func containsAnyOf<T, S: Sequence>(
    values elements: T...,
    where equality: @escaping (T, T) -> Bool
) -> ParameterMatcher<S> where T == S.Element {
    containsAnyOf(elements, where: equality)
}
/**
 * Matcher for sequences of elements that checks if at least one of the passed elements matches the passed sequence.
 * - parameter elements: Elements that are used for matching.
 * - parameter equality: Closure for determining equality of elements that don't conform to `Equatable`.
 * - returns: ParameterMatcher object.
 */
public func containsAnyOf<IN: Sequence, OUT: Sequence>(
    _ elements: IN,
    where equality: @escaping (IN.Element, IN.Element) -> Bool
) -> ParameterMatcher<OUT> where IN.Element == OUT.Element {
    ParameterMatcher { sequence in
        elements.contains { element in
            sequence.contains {
                equality($0, element)
            }
        }
    }
}

/**
 * Matcher for sequences of `Equatable` elements that checks if at least one of the passed elements matches the passed sequence.
 * - parameter elements: Variadic elements that are used for matching.
 * - returns: ParameterMatcher object.
 */
public func containsAnyOf<T: Equatable, S: Sequence>(
    values elements: T...
) -> ParameterMatcher<S> where T == S.Element {
    containsAnyOf(elements)
}
/**
 * Matcher for sequences of `Equatable` elements that checks if at least one of the passed elements matches the passed sequence.
 * - parameter elements: Elements that are used for matching.
 * - returns: ParameterMatcher object.
 */
public func containsAnyOf<IN: Sequence, OUT: Sequence>(
    _ elements: IN
) -> ParameterMatcher<OUT> where IN.Element: Equatable, IN.Element == OUT.Element {
    containsAnyOf(elements, where: ==)
}

/**
 * Matcher for sequences of `Hashable` elements that checks if at least one of the passed elements matches the passed sequence.
 * - parameter elements: Variadic elements that are used for matching.
 * - returns: ParameterMatcher object.
 */
public func containsAnyOf<T: Hashable, S: Sequence>(
    values elements: T...
) -> ParameterMatcher<S> where T == S.Element {
    containsAnyOf(elements)
}
/**
 * Matcher for sequences of `Hashable` elements that checks if at least one of the passed elements matches the passed sequence.
 * - parameter elements: Elements that are used for matching.
 * - returns: ParameterMatcher object.
 */
public func containsAnyOf<IN: Sequence, OUT: Sequence>(
    _ elements: IN
) -> ParameterMatcher<OUT> where IN.Element: Hashable, IN.Element == OUT.Element {
    ParameterMatcher { sequence in
        let set = Set(sequence)
        let elementsSet = Set(elements)
        return !set.isDisjoint(with: elementsSet)
    }
}


// MARK: - Contains ALL of the elements.
/**
 * Matcher for sequences of elements that checks if all of the passed elements match the passed sequence.
 * - parameter elements: Variadic elements that are used for matching.
 * - parameter equality: Closure for determining equality of elements that don't conform to `Equatable`.
 * - returns: ParameterMatcher object.
 * - NOTE: When matching an Array, this matcher expects items as many times as they are present in the passed elements.
 */
public func containsAllOf<T, S: Sequence>(
    values elements: T...,
    where equality: @escaping (T, T) -> Bool
) -> ParameterMatcher<S> where T == S.Element {
    containsAllOf(elements, where: equality)
}
/**
 * Matcher for sequences of elements that checks if all of the passed elements match the passed sequence.
 * - parameter elements: Elements that are used for matching.
 * - parameter equality: Closure for determining equality of elements that don't conform to `Equatable`.
 * - returns: ParameterMatcher object.
 * - NOTE: An element passed more than once must be in the matched sequence at least as many times.
 */
public func containsAllOf<IN: Sequence, OUT: Sequence>(
    _ elements: IN,
    where equality: @escaping (IN.Element, IN.Element) -> Bool
) -> ParameterMatcher<OUT> where IN.Element == OUT.Element {
    ParameterMatcher { sequence in
        var matchedSequence = sequence.map { (element: $0, matched: false) }
        for element in elements {
            if let matchedIndex = matchedSequence.firstIndex(where: { !$0.matched && equality($0.element, element) }) {
                matchedSequence[matchedIndex].matched = true
            } else {
                return false
            }
        }
        return true
    }
}

/**
 * Matcher for sequences of `Equatable` elements that checks if all of the passed elements match the passed sequence.
 * - parameter elements: Variadic elements that are used for matching.
 * - returns: ParameterMatcher object.
 * - NOTE: An element passed more than once must be in the matched sequence at least as many times.
 */
public func containsAllOf<T: Equatable, S: Sequence>(
    values elements: T...
) -> ParameterMatcher<S> where T == S.Element {
    containsAllOf(elements)
}
/**
 * Matcher for sequences of `Equatable` elements that checks if all of the passed elements match the passed sequence.
 * - parameter elements: Elements that are used for matching.
 * - returns: ParameterMatcher object.
 * - NOTE: An element passed more than once must be in the matched sequence at least as many times.
 */
public func containsAllOf<IN: Sequence, OUT: Sequence>(
    _ elements: IN
) -> ParameterMatcher<OUT> where IN.Element: Equatable, IN.Element == OUT.Element {
    containsAllOf(elements, where: ==)
}

/**
 * Matcher for sequences of `Hashable` elements that checks if all of the passed elements match the passed sequence.
 * - parameter elements: Variadic elements that are used for matching.
 * - returns: ParameterMatcher object.
 * - NOTE: An element passed more than once must be in the matched sequence at least as many times.
 */
public func containsAllOf<T: Hashable>(values elements: T...) -> ParameterMatcher<[T]> {
    containsAllOf(elements)
}
/**
 * Matcher for sequences of `Hashable` elements that checks if all of the passed elements match the passed sequence.
 * - parameter elements: Elements that are used for matching.
 * - returns: ParameterMatcher object.
 * - NOTE: An element passed more than once must be in the matched sequence at least as many times.
 */
public func containsAllOf<IN: Sequence, OUT: Sequence>(
    _ elements: IN
) -> ParameterMatcher<OUT> where IN.Element: Hashable, IN.Element == OUT.Element {
    ParameterMatcher { sequence in
        let sequenceDictionary: [IN.Element: Int] = sequence.reduce(into: [:]) { dictionary, element in
            dictionary[element, default: 0] += 1
        }
        let elementsDictionary: [IN.Element: Int] = elements.reduce(into: [:]) { dictionary, element in
            dictionary[element, default: 0] += 1
        }

        return elementsDictionary.allSatisfy { key, element in
            sequenceDictionary[key].map { $0 >= element } ?? false
        }
    }
}
/**
 * Matcher for `Set`s of `Hashable` elements that checks if all of the passed elements match the passed `Set`.
 * - parameter elements: Elements that are used for matching.
 * - returns: ParameterMatcher object.
 */
public func containsAllOf<IN: Sequence, OUT: Sequence>(
    _ elements: IN
) -> ParameterMatcher<OUT> where IN.Element: Hashable, IN.Element == OUT.Element, IN: SetAlgebra {
    return ParameterMatcher { sequence in
        let set = Set(sequence)
        let elementsSet = Set(elements)
        return set.isSuperset(of: elementsSet)
    }
}


// MARK: - Contains NONE of the elements.
/**
 * Matcher for sequences of elements that checks if none of the passed elements match the passed sequence.
 * - parameter elements: Variadic elements that are used for matching.
 * - parameter equality: Closure for determining equality of elements that don't conform to `Equatable`.
 * - returns: ParameterMatcher object.
 */
public func containsNoneOf<T, S: Sequence>(
    values elements: T...
    , where equality: @escaping (T, T) -> Bool
) -> ParameterMatcher<S> where T == S.Element {
    containsNoneOf(elements, where: equality)
}
/**
 * Matcher for sequences of elements that checks if none of the passed elements match the passed sequence.
 * - parameter elements: Elements that are used for matching.
 * - parameter equality: Closure for determining equality of elements that don't conform to `Equatable`.
 * - returns: ParameterMatcher object.
 */
public func containsNoneOf<IN: Sequence, OUT: Sequence>(
    _ elements: IN,
    where equality: @escaping (IN.Element, IN.Element) -> Bool
) -> ParameterMatcher<OUT> where IN.Element == OUT.Element {
    not(containsAnyOf(elements, where: equality))
}

/**
 * Matcher for sequences of `Equatable` elements that checks if none of the passed elements match the passed sequence.
 * - parameter elements: Variadic elements that are used for matching.
 * - returns: ParameterMatcher object.
 */
public func containsNoneOf<T: Equatable, S: Sequence>(
    values elements: T...
) -> ParameterMatcher<S> where T == S.Element {
    containsNoneOf(elements)
}
/**
 * Matcher for sequences of `Equatable` elements that checks if none of the passed elements match the passed sequence.
 * - parameter elements: Elements that are used for matching.
 * - returns: ParameterMatcher object.
 */
public func containsNoneOf<IN: Sequence, OUT: Sequence>(
    _ elements: IN
) -> ParameterMatcher<OUT> where IN.Element: Equatable, IN.Element == OUT.Element {
    containsNoneOf(elements, where: ==)
}

/**
 * Matcher for sequences of `Hashable` elements that checks if none of the passed elements match the passed sequence.
 * - parameter elements: Variadic elements that are used for matching.
 * - returns: ParameterMatcher object.
 */
public func containsNoneOf<T: Hashable, S: Sequence>(
    values elements: T...
) -> ParameterMatcher<S> where T == S.Element {
    containsNoneOf(elements)
}
/**
 * Matcher for sequences of `Hashable` elements that checks if none of the passed elements match the passed sequence.
 * - parameter elements: Elements that are used for matching.
 * - returns: ParameterMatcher object.
 */
public func containsNoneOf<IN: Sequence, OUT: Sequence>(
    _ elements: IN
) -> ParameterMatcher<OUT> where IN.Element: Hashable, IN.Element == OUT.Element {
    not(containsAnyOf(elements))
}


// MARK: - Has length N (exact, at least, at most).
/**
 * Matcher for collections of elements that checks if the collection is exactly N elements long.
 * - parameter requiredExactLength: Required length of the matching collection.
 * - returns: ParameterMatcher object.
 */
public func hasLength<C: Collection>(exactly requiredExactLength: Int) -> ParameterMatcher<C> {
    ParameterMatcher { collection in
        collection.count == requiredExactLength
    }
}

/**
 * Matcher for collections of elements that checks if the collection is at least N elements long with the option to include the number itself (default).
 * - parameter requiredMinimumLength: Required minimum length of the matching collection.
 * - parameter inclusive: Whether the minimum length itself should be included.
 * - returns: ParameterMatcher object.
 */
public func hasLength<C: Collection>(
    atLeast requiredMinimumLength: Int,
    inclusive: Bool = true
) -> ParameterMatcher<C> {
    ParameterMatcher { collection in
        collection.count > requiredMinimumLength || (inclusive && collection.count == requiredMinimumLength)
    }
}

/**
 * Matcher for collections of elements that checks if the collection is at most N elements long with the option to include the number itself (default).
 * - parameter requiredMaximumLength: Required maximum length of the matching collection.
 * - parameter inclusive: Whether the maximum length itself should be included.
 * - returns: ParameterMatcher object.
 */
public func hasLength<C: Collection>(
    atMost requiredMaximumLength: Int,
    inclusive: Bool = true
) -> ParameterMatcher<C> {
    ParameterMatcher { collection in
        collection.count < requiredMaximumLength || (inclusive && collection.count == requiredMaximumLength)
    }
}

/**
 * Matcher for collections of elements that checks if the collection's length is in a range, such as `1..<3`, `1...3` or `2...`.
 * - parameter requiredLengthRange: The lengths that match, with the range's own bounds: `1..<3` matches 1 and 2.
 * - returns: ParameterMatcher object.
 */
public func hasLength<C: Collection>(inRange requiredLengthRange: some RangeExpression<Int>) -> ParameterMatcher<C> {
    ParameterMatcher { collection in
        requiredLengthRange.contains(collection.count)
    }
}

/**
 * Matcher for collections of elements that checks if the collection is between N and M elements long, both bounds
 * included or both excluded.
 * - parameter requiredLengthRange: Required length range of the matching collection. Its upper bound counts as a
 *   bound, despite the half-open range: `1..<3` with `inclusive: true` matches 3.
 * - parameter inclusive: Whether the length range bounds should be included.
 * - returns: ParameterMatcher object.
 */
@available(*, deprecated, message: "Use hasLength(inRange:) with the range you mean, such as 1...3 or 2..<4.")
public func hasLength<C: Collection>(
    inRange requiredLengthRange: CountableRange<Int>,
    inclusive: Bool
) -> ParameterMatcher<C> {
    hasLength(atLeast: requiredLengthRange.lowerBound, inclusive: inclusive)
        .and(hasLength(atMost: requiredLengthRange.upperBound, inclusive: inclusive))
}
