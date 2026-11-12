/// A stub of one member and its argument matchers, with the answers queued for matching calls.
public protocol Stub {
    /// The stubbed member, as failure messages name it, such as `greet(name: String) -> String`.
    var method: String { get }
}

/// A stub of a member whose arguments are `IN`, which returns `OUT`, throws `ERROR` and runs `IMPL` closures.
///
/// The stubbing proxies create it; tests reach it through `when(…)` and the `then…` calls.
public class ConcreteStub<IN, OUT, ERROR: Error, IMPL>: Stub {
    /// The stubbed member, as failure messages name it.
    public let method: String
    let parameterMatchers: [ParameterMatcher<IN>]
    private let actions = Locked<[StubAction<OUT, ERROR, IMPL>]>([])

    init(method: String, parameterMatchers: [ParameterMatcher<IN>]) {
        self.method = method
        self.parameterMatchers = parameterMatchers
    }

    func appendAction(_ action: StubAction<OUT, ERROR, IMPL>) {
        actions.withLock { $0.append(action) }
    }

    /// The action for the next call. Each action is used once, in order, and the last one repeats.
    /// `nil` if the stubbing wasn't finished with a `then…` call.
    func nextAction() -> StubAction<OUT, ERROR, IMPL>? {
        actions.withLock { actions in
            actions.count > 1 ? actions.removeFirst() : actions.first
        }
    }

    func matches(_ parameters: IN) -> Bool {
        firstMismatch(in: parameters) == nil
    }

    /// The index of the first argument whose matcher rejects `parameters`, or `nil` if they all accept it. Like
    /// matching, it stops at that argument, so a capturing matcher after it doesn't run.
    func firstMismatch(in parameters: IN) -> Int? {
        parameterMatchers.firstIndex { !$0.matches(parameters) }
    }
}

/// A stub of a class mock's member, which can also call the real implementation.
public final class ClassConcreteStub<IN, OUT, ERROR: Error, IMPL>: ConcreteStub<IN, OUT, ERROR, IMPL> { }
