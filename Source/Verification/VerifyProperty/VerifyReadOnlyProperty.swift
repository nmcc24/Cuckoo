/// The verification proxy's handle on a read-only property: `verify(mock).name.get()`.
public struct VerifyReadOnlyProperty<T> {
    private let manager: MockManager
    private let name: String
    private let callMatcher: CallMatcher
    private let sourceLocation: SourceLocation

    /// Checks the property's reads against the call matcher `verify` was given.
    @discardableResult
    public func get() -> __DoNotUse<Void, T> {
        return manager.verify(getterName(name), callMatcher: callMatcher, parameterMatchers: [] as [ParameterMatcher<Void>], sourceLocation: sourceLocation)
    }
    
    /// Creates the handle of the property `name`. The generated verification proxy creates it.
    public init(manager: MockManager, name: String, callMatcher: CallMatcher, sourceLocation: SourceLocation) {
        self.manager = manager
        self.name = name
        self.callMatcher = callMatcher
        self.sourceLocation = sourceLocation
    }
}
