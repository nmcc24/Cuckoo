/// Decides whether an argument matches, in stubbing and verification.
///
/// Cuckoo's matcher functions, such as `any()` or `equal(to:)`, return one. Write your own with a
/// closure: `ParameterMatcher<Int> { $0.isMultiple(of: 2) }`.
public struct ParameterMatcher<T>: Matchable {
    private let matchesFunction: (T) -> Bool
    
    /// Creates a matcher that accepts the arguments `matchesFunction` returns `true` for, every argument by default.
    public init(matchesFunction: @escaping (T) -> Bool = { _ in true }) {
        self.matchesFunction = matchesFunction
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

/// `Optional`, as a protocol, so ``ParameterMatcher`` can match optional arguments. Only `Optional` conforms.
public protocol CuckooOptionalType {
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
