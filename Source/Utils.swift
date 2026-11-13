internal func getterName(_ property: String) -> String {
    return property + "#get"
}

internal func setterName(_ property: String) -> String {
    return property + "#set"
}

/// Matches an argument of type `IN` by mapping it to the type `matchable` matches. Generated proxies use it to
/// match one parameter of a call's argument tuple.
public func wrap<M: Matchable, IN>(matchable: M, mapping: @escaping (IN) -> M.MatchedType) -> ParameterMatcher<IN> {
    let matcher = matchable.matcher
    // The generated mocks' mappings pick an element of the arguments' tuple and capture nothing, but they can't be
    // `@Sendable`: that would need each generic parameter's metatype to be `SendableMetatype`.
    return ParameterMatcher(uncheckedSendable: {
        matcher.matches(mapping($0))
    })
}

/// Matches an argument of type `IN` by mapping it to the optional type `matchable` matches. Generated proxies use
/// it to match one optional parameter of a call's argument tuple.
public func wrap<M: OptionalMatchable, IN, O>(matchable: M, mapping: @escaping (IN) -> M.OptionalMatchedType?) -> ParameterMatcher<IN> where M.OptionalMatchedType == O {
    let matcher = matchable.optionalMatcher
    // See the other `wrap(matchable:mapping:)`.
    return ParameterMatcher(uncheckedSendable: {
        matcher.matches(mapping($0))
    })
}

/// Where a check was written, so a failure is reported there: the `#file`, `#fileID`, `#filePath`, `#line` and
/// `#column` of the call.
public typealias SourceLocation = (file: StaticString, fileID: String, filePath: String, line: Int, column: Int)

/// Used by generated mocks to pass on a `sending` value that region isolation can't prove disconnected:
/// - a `sending` argument, which the mock keeps for verification and also passes to the default
///   implementation or superclass;
/// - a `sending` result, which comes from a stub that may hand out the same value again.
/// Only acceptable because mocks are test doubles that don't run that code concurrently.
public struct __SendingArgument<T>: @unchecked Sendable {
    public let value: T

    public init(_ value: T) {
        self.value = value
    }
}

/// `count` as a number of calls in a failure message: "1 time", "2 times".
func timesDescription(_ count: Int) -> String {
    count == 1 ? "1 time" : "\(count) times"
}
