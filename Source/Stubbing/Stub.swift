public protocol Stub {
    var method: String { get }
}

public class ConcreteStub<IN, OUT, ERROR: Error>: Stub {
    public let method: String
    let parameterMatchers: [ParameterMatcher<IN>]
    private let actions = Locked<[StubAction<IN, OUT, ERROR>]>([])

    init(method: String, parameterMatchers: [ParameterMatcher<IN>]) {
        self.method = method
        self.parameterMatchers = parameterMatchers
    }

    func appendAction(_ action: StubAction<IN, OUT, ERROR>) {
        actions.withLock { $0.append(action) }
    }

    /// The action for the next call. Each action is used once, in order, and the last one repeats.
    /// `nil` if the stubbing wasn't finished with a `then…` call.
    func nextAction() -> StubAction<IN, OUT, ERROR>? {
        actions.withLock { actions in
            actions.count > 1 ? actions.removeFirst() : actions.first
        }
    }

    func matches(_ parameters: IN) -> Bool {
        parameterMatchers.allSatisfy { $0.matches(parameters) }
    }
}

public class ClassConcreteStub<IN, OUT, ERROR: Error>: ConcreteStub<IN, OUT, ERROR> { }
