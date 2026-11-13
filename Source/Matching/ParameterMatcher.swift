/// Decides whether an argument matches, in stubbing and verification.
///
/// Cuckoo's matcher functions, such as `any()` or `equal(to:)`, return one. Write your own with a
/// closure: `ParameterMatcher<Int> { $0.isMultiple(of: 2) }`.
///
/// A matcher is `Sendable`: a mock may be called from any task, and its stubs' matchers run there. So the closure is
/// `@Sendable` and may capture only `Sendable` values; the argument it checks needn't be `Sendable`.
public struct ParameterMatcher<T>: Matchable, Sendable {
    private let matchesFunction: @Sendable (T) -> Bool

    /// Creates a matcher that accepts the arguments `matchesFunction` returns `true` for, every argument by default.
    public init(matchesFunction: @escaping @Sendable (T) -> Bool = { _ in true }) {
        self.matchesFunction = matchesFunction
    }

    /// Creates a matcher from a closure that isn't `@Sendable`, such as one that captures a non-`Sendable` value.
    ///
    /// Nothing checks that the closure is safe to call from the task that calls the mock. Capture only `Sendable`
    /// values and use ``init(matchesFunction:)`` instead.
    @available(*, deprecated, message: "A matcher may run on any task that calls the mock; capture only Sendable values and use init(matchesFunction:).")
    @_disfavoredOverload
    public init(unchecked matchesFunction: @escaping (T) -> Bool) {
        self.init(uncheckedSendable: matchesFunction)
    }

    /// Creates a matcher from a closure that Cuckoo itself knows is safe to call from any task, but can't prove so.
    @_disfavoredOverload
    init(uncheckedSendable matchesFunction: @escaping (T) -> Bool) {
        let function = UncheckedSendable(matchesFunction)
        self.matchesFunction = { function.value($0) }
    }

    /// The matcher itself.
    public var matcher: ParameterMatcher<T> {
        return self
    }

    /// Whether `input` matches.
    public func matches(_ input: T) -> Bool {
        return matchesFunction(input)
    }
}

/// A value the deprecated non-`Sendable` matcher APIs keep inside a `Sendable` matcher. Unchecked on purpose: those
/// APIs are deprecated because nothing makes the value safe to use from another task.
struct UncheckedSendable<Value>: @unchecked Sendable {
    let value: Value

    init(_ value: Value) {
        self.value = value
    }
}

/// An object kept for its identity. Comparing identities with `===` reads no state of the object, so this is safe
/// whether or not the object is `Sendable`.
struct Identity<Object: AnyObject>: @unchecked Sendable {
    let object: Object?

    func isSame(as other: Object?) -> Bool {
        object === other
    }
}

/// `Optional`, as a protocol, so ``ParameterMatcher`` can match optional arguments. Only `Optional` conforms.
public protocol CuckooOptionalType: SendableMetatype {
    /// The wrapped type.
    associatedtype Wrapped

    /// Wraps `optional` as `Self`.
    static func from(optional: Optional<Wrapped>) -> Self
}

extension Optional: CuckooOptionalType {
    /// Returns `optional` unchanged.
    public static func from(optional: Optional<Wrapped>) -> Optional<Wrapped> {
        return optional
    }
}

extension ParameterMatcher: OptionalMatchable where T: CuckooOptionalType {
    /// A matcher of optionals matches optional arguments of the same type.
    public typealias OptionalMatchedType = T.Wrapped

    /// This matcher, for an optional argument.
    public var optionalMatcher: ParameterMatcher<T.Wrapped?> {
        return ParameterMatcher<T.Wrapped?> { other in
            self.matchesFunction(T.from(optional: other))
        }
    }
}
