/// A matcher that's `Sendable`: like a ``ParameterMatcher``, but its closure is `@Sendable`, so it can match calls
/// from any task.
///
/// A `Sendable` mock can be called from any task, so its stubs only take `Sendable` matchers. Cuckoo's matcher
/// functions return one whenever the values they keep are `Sendable`, so you rarely name this type. Write your
/// own with a `@Sendable` closure: `SendableMatcher<Int> { $0.isMultiple(of: 2) }`.
public struct SendableMatcher<T>: _SendableMatchable {
    private let matchesFunction: @Sendable (T) -> Bool

    /// Creates a matcher that accepts the arguments `matchesFunction` returns `true` for, every argument by default.
    public init(matchesFunction: @escaping @Sendable (T) -> Bool = { _ in true }) {
        self.matchesFunction = matchesFunction
    }

    /// The matcher itself.
    public var sendableMatcher: SendableMatcher<T> {
        self
    }

    /// The matcher, as a ``ParameterMatcher``.
    public var matcher: ParameterMatcher<T> {
        ParameterMatcher(matchesFunction: matchesFunction)
    }

    /// Whether `input` matches.
    public func matches(_ input: T) -> Bool {
        matchesFunction(input)
    }
}

extension SendableMatcher: _OptionalMatchable where T: CuckooOptionalType {}

extension SendableMatcher: _SendableOptionalMatchable where T: CuckooOptionalType {
    /// A matcher of optionals matches optional arguments of the same type.
    public typealias OptionalMatchedType = T.Wrapped

    /// This matcher, for an optional argument.
    public var sendableOptionalMatcher: SendableMatcher<T.Wrapped?> {
        SendableMatcher<T.Wrapped?> { other in
            self.matchesFunction(T.from(optional: other))
        }
    }

    /// This matcher, for an optional argument, as a ``ParameterMatcher``.
    public var optionalMatcher: ParameterMatcher<T.Wrapped?> {
        sendableOptionalMatcher.matcher
    }
}

/// A ``_Matchable`` value that's `Sendable`, so a `Sendable` mock's stubs can keep it.
///
/// ``SendableMatcher`` and the standard types Cuckoo makes matchable conform.
public protocol _SendableMatchable: _Matchable, Sendable {
    /// The matcher this value stands for, usually `equal(to:)` of the value itself.
    var sendableMatcher: SendableMatcher<MatchedType> { get }
}

public extension _SendableMatchable {
    /// The matcher this value stands for.
    var matcher: ParameterMatcher<MatchedType> {
        sendableMatcher.matcher
    }
}

/// An ``_OptionalMatchable`` value that's `Sendable`, so a `Sendable` mock's stubs can keep it.
public protocol _SendableOptionalMatchable: _OptionalMatchable, Sendable {
    /// The matcher for an optional argument: it matches when the argument holds an equal value.
    var sendableOptionalMatcher: SendableMatcher<OptionalMatchedType?> { get }
}

public extension _SendableOptionalMatchable {
    /// The matcher for an optional argument.
    var optionalMatcher: ParameterMatcher<OptionalMatchedType?> {
        sendableOptionalMatcher.matcher
    }
}
