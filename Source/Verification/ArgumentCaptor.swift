/// Captures the arguments a matcher sees. Use it in verification rather than in stubbing.
///
/// It's safe to use from several tasks at once, and `Sendable` when its values are: a stub's matchers run on
/// whichever thread makes the call.
public final class ArgumentCaptor<T> {
    private let values = Locked<[T]>([])

    /// The last captured argument, if any.
    public var value: T? {
        values.withLock { $0.last }
    }

    /// All captured arguments, oldest first.
    public var allValues: [T] {
        values.withLock { $0 }
    }

    public init() {
    }

    /// A parameter matcher that matches any argument and captures it.
    public func capture() -> ParameterMatcher<T> {
        ParameterMatcher { value in
            self.values.withLock { $0.append(value) }
            return true
        }
    }
}

extension ArgumentCaptor: Sendable where T: Sendable {
}
