/// The verification proxy's handle on a read-write property: `verify(mock).name.get()` and `verify(mock).name.set(…)`.
public struct VerifyProperty<T> {
    private let manager: MockManager
    private let name: String
    private let callMatcher: CallMatcher
    private let sourceLocation: SourceLocation

    /// Checks the property's reads against the call matcher `verify` was given.
    @discardableResult
    public func get() -> __DoNotUse<Void, T> {
        return manager.verify(getterName(name), callMatcher: callMatcher, parameterMatchers: [] as [ParameterMatcher<Void>], sourceLocation: sourceLocation)
    }

    /// Checks the property's assignments whose new value matches `matcher` against the call matcher `verify`
    /// was given.
    @discardableResult
    public func set<M: Matchable>(_ matcher: M) -> __DoNotUse<T, Void> where M.MatchedType == T {
        return manager.verify(setterName(name), callMatcher: callMatcher, parameterMatchers: [matcher.matcher], sourceLocation: sourceLocation)
    }
    
    /// Creates the handle of the property `name`. The generated verification proxy creates it.
    public init(manager: MockManager, name: String, callMatcher: CallMatcher, sourceLocation: SourceLocation) {
        self.manager = manager
        self.name = name
        self.callMatcher = callMatcher
        self.sourceLocation = sourceLocation
    }
}

/// The verification proxy's handle on a optional read-write property: `verify(mock).name.get()` and `verify(mock).name.set(…)`.
public struct VerifyOptionalProperty<T> {
    private let manager: MockManager
    private let name: String
    private let callMatcher: CallMatcher
    private let sourceLocation: SourceLocation

    /// Checks the property's reads against the call matcher `verify` was given.
    @discardableResult
    public func get() -> __DoNotUse<Void, T> {
        return manager.verify(getterName(name), callMatcher: callMatcher, parameterMatchers: [] as [ParameterMatcher<Void>], sourceLocation: sourceLocation)
    }

    /// Checks the property's assignments whose new value matches `matcher` against the call matcher `verify`
    /// was given.
    @discardableResult
    public func set<M: OptionalMatchable>(_ matcher: M) -> __DoNotUse<T?, Void> where M.OptionalMatchedType == T {
        return manager.verify(setterName(name), callMatcher: callMatcher, parameterMatchers: [matcher.optionalMatcher], sourceLocation: sourceLocation)
    }

    /// Creates the handle of the property `name`. The generated verification proxy creates it.
    public init(manager: MockManager, name: String, callMatcher: CallMatcher, sourceLocation: SourceLocation) {
        self.manager = manager
        self.name = name
        self.callMatcher = callMatcher
        self.sourceLocation = sourceLocation
    }
}
