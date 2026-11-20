/// Captures the arguments of the calls a `verify` or a stub takes.
///
/// A captor captures an argument only when every matcher of that call accepted it and the `verify` passed, or the
/// stub answered the call: a call another matcher rejected, or that a failed `verify` looked at, isn't captured.
///
/// It's safe to use from several tasks at once, and `Sendable` when its values are: a stub's matchers run on
/// whichever thread makes the call.
///
/// Inside ``inOrder(strict:fileID:filePath:line:column:_:)``, the `verify` calls are checked when the block ends,
/// so the captor fills only then: read it after `inOrder` returns.
///
/// It can't capture a closure parameter that isn't `@escaping`, which can't outlive the call it was passed to. A
/// `verify` captures a stand-in that crashes when called, and a stub's captor crashes when the stubbed call returns.
/// Call such a closure from the stub's `then` closure instead.
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
