/// Captures the arguments of the calls a `verify` or a stub takes.
///
/// A captor captures an argument only when every matcher of that call accepted it and the `verify` passed, or the
/// stub answered the call: a call another matcher rejected, or that a failed `verify` looked at, isn't captured.
///
/// It's safe to use from several tasks at once, and `Sendable` when its values are: a stub's matchers run on
/// whichever thread makes the call.
///
/// Inside ``eventually(timeout:pollingInterval:_:)``, a `verify` that passes on a run that fails elsewhere in the
/// block captures again on the next run, so ``allValues`` can repeat arguments. Read ``value`` there, or create
/// the captor inside the block.
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

    /// Creates a captor with no captured arguments.
    public init() {
    }

    /// A parameter matcher that matches any argument and captures it.
    public func capture() -> ParameterMatcher<T> {
        ParameterMatcher { value in
            self.record(value)
            return true
        }
    }

    /// Captures `value` once the matching in progress takes the call, or at once outside a stub or `verify`.
    fileprivate func record(_ value: T) {
        guard let pending = PendingCaptures.current else {
            values.withLock { $0.append(value) }
            return
        }
        pending.add {
            self.values.withLock { $0.append(value) }
        }
    }
}

extension ArgumentCaptor: Sendable where T: Sendable {
    /// A parameter matcher that matches any argument and captures it. It's `Sendable`, so a `Sendable` mock's
    /// stubs can keep it.
    public func capture() -> SendableMatcher<T> {
        SendableMatcher { value in
            self.record(value)
            return true
        }
    }
}
