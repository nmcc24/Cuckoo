internal func getterName(_ property: String) -> String {
    return property + "#get"
}

internal func setterName(_ property: String) -> String {
    return property + "#set"
}

public func wrap<M: Matchable, IN>(matchable: M, mapping: @escaping (IN) -> M.MatchedType) -> ParameterMatcher<IN> {
    return ParameterMatcher {
        return matchable.matcher.matches(mapping($0))
    }
}

public func wrap<M: OptionalMatchable, IN, O>(matchable: M, mapping: @escaping (IN) -> M.OptionalMatchedType?) -> ParameterMatcher<IN> where M.OptionalMatchedType == O {
    return ParameterMatcher {
        return matchable.optionalMatcher.matches(mapping($0))
    }
}

public typealias SourceLocation = (file: StaticString, fileID: String, filePath: String, line: Int, column: Int)

/// Used by generated mocks to forward a `sending` argument. The mock keeps the argument for verification
/// and also passes it on to the default implementation or superclass, so region isolation can't prove it
/// disconnected. Only acceptable because mocks are test doubles that don't run that code concurrently.
public struct __SendingArgument<T>: @unchecked Sendable {
    public let value: T

    public init(_ value: T) {
        self.value = value
    }
}
