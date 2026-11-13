internal func getterName(_ property: String) -> String {
    return property + "#get"
}

internal func setterName(_ property: String) -> String {
    return property + "#set"
}

/// Matches an argument of type `IN` by mapping it to the type `matchable` matches. Generated proxies use it to
/// match one parameter of a call's argument tuple.
public func wrap<M: _Matchable, IN>(matchable: M, mapping: @escaping (IN) -> M.MatchedType) -> ParameterMatcher<IN> {
    return ParameterMatcher {
        return matchable.matcher.matches(mapping($0))
    }
}

/// Matches an argument of type `IN` by mapping it to the optional type `matchable` matches. Generated proxies use
/// it to match one optional parameter of a call's argument tuple.
public func wrap<M: _OptionalMatchable, IN, O>(matchable: M, mapping: @escaping (IN) -> M.OptionalMatchedType?) -> ParameterMatcher<IN> where M.OptionalMatchedType == O {
    return ParameterMatcher {
        return matchable.optionalMatcher.matches(mapping($0))
    }
}

/// Matches an argument of type `IN` by reading, at `keyPath`, the value `matchable` matches. A `Sendable` mock's
/// generated stubbing proxies use it to match one parameter of a call's argument tuple, such as `\.0`.
public func wrap<M: _SendableMatchable, IN>(
    matchable: M,
    at keyPath: any KeyPath<IN, M.MatchedType> & Sendable
) -> SendableMatcher<IN> {
    let matcher = matchable.sendableMatcher
    return SendableMatcher {
        matcher.matches($0[keyPath: keyPath])
    }
}

/// Matches an argument of type `IN` by reading, at `keyPath`, the optional value `matchable` matches. A `Sendable`
/// mock's generated stubbing proxies use it to match one optional parameter of a call's argument tuple.
public func wrap<M: _SendableOptionalMatchable, IN>(
    matchable: M,
    at keyPath: any KeyPath<IN, M.OptionalMatchedType?> & Sendable
) -> SendableMatcher<IN> {
    let matcher = matchable.sendableOptionalMatcher
    return SendableMatcher {
        matcher.matches($0[keyPath: keyPath])
    }
}

/// Where a check was written, so a failure is reported there: the `#fileID`, `#filePath`, `#line` and `#column` of
/// the call. XCTest gets the full `filePath`, which Xcode needs to show the failure on the line.
public typealias SourceLocation = (fileID: String, filePath: StaticString, line: Int, column: Int)

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
