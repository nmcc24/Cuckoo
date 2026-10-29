public protocol Stub {
    var method: String { get }
}

public class ConcreteStub<IN, OUT, ERROR: Error, IMPL>: Stub {
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

public class ClassConcreteStub<IN, OUT, ERROR: Error, IMPL>: ConcreteStub<IN, OUT, ERROR, IMPL> { }
