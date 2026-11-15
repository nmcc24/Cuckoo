extension Set: _Matchable where Element: _Matchable, Element == Element.MatchedType {
    /// The arguments it matches: `Set<Element>`.
    public typealias MatchedType = Set<Element>

    /// Matches an equal set.
    public var matcher: ParameterMatcher<Set<Element>> {
        ParameterMatcher<Set<Element>> { other in
            self == other
        }
    }
}

extension Set: _SendableMatchable where Element: _SendableMatchable, Element == Element.MatchedType {
    /// Matches an equal set.
    public var sendableMatcher: SendableMatcher<Set<Element>> {
        let elements = self
        return SendableMatcher<Set<Element>> { other in
            elements == other
        }
    }
}
