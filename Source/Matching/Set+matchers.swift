extension Set: Matchable where Element: Matchable, Element == Element.MatchedType {
    public typealias MatchedType = Set<Element>

    public var matcher: ParameterMatcher<Set<Element>> {
        // Each element's matcher, so the matcher captures no element: a set's elements are distinct, so a set of the
        // same size whose every element matches one of them is equal.
        let matchers = map(\.matcher)
        return ParameterMatcher<Set<Element>> { other in
            other.count == matchers.count && other.allSatisfy { element in matchers.contains { $0.matches(element) } }
        }
    }
}
