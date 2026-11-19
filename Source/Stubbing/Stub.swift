/// A stub of one member and its argument matchers, with the answers queued for matching calls.
public protocol Stub {
    /// The stubbed member, as failure messages name it, such as `greet(name: String) -> String`.
    var method: String { get }
}

/// A stub that can name the argument and return types it was made for, which tell apart the stubs of a generic
/// member made with different type arguments.
protocol TypedStub: Stub {
    var types: String { get }
}

/// A stub of a member whose arguments are `IN`, which returns `OUT`, throws `ERROR` and runs `IMPL` closures.
///
/// The stubbing proxies create it; tests reach it through `when(…)` and the `then…` calls.
public class ConcreteStub<IN, OUT, ERROR: Error, IMPL>: Stub, TypedStub {
    /// The stubbed member, as failure messages name it.
    public let method: String
    let parameterMatchers: [ParameterMatcher<IN>]
    private let actions = Locked<[StubAction<OUT, ERROR, IMPL>]>([])

    var types: String {
        ConcreteStub.types(in: IN.self, out: OUT.self)
    }

    /// Arguments `IN` and result `OUT` as failure messages show them, such as `(String) -> Int`.
    static func types(in _: IN.Type, out _: OUT.Type) -> String {
        let arguments = "\(IN.self)"
        return (isParenthesized(arguments) ? arguments : "(\(arguments))") + " -> \(OUT.self)"
    }

    /// Whether `type` is one pair of parentheses, as a tuple or `()` is, rather than a type that starts with one,
    /// such as `(String) -> Int`.
    private static func isParenthesized(_ type: String) -> Bool {
        guard type.first == "(" else {
            return false
        }
        var depth = 0
        for (offset, character) in type.enumerated() {
            if character == "(" {
                depth += 1
            } else if character == ")" {
                depth -= 1
                if depth == 0 {
                    return offset == type.count - 1
                }
            }
        }
        return false
    }

    init(method: String, parameterMatchers: [ParameterMatcher<IN>]) {
        self.method = method
        self.parameterMatchers = parameterMatchers
    }

    func appendAction(_ action: StubAction<OUT, ERROR, IMPL>) {
        actions.withLock { $0.append(action) }
    }

    /// Appends `newActions` under one lock, so a call from another task can't take the first one before the rest
    /// are in, and get it twice.
    func appendActions(_ newActions: [StubAction<OUT, ERROR, IMPL>]) {
        actions.withLock { $0.append(contentsOf: newActions) }
    }

    /// The action for the next call. Each action is used once, in order, and the last one repeats.
    /// `nil` if the stubbing wasn't finished with a `then…` call.
    func nextAction() -> StubAction<OUT, ERROR, IMPL>? {
        actions.withLock { actions in
            actions.count > 1 ? actions.removeFirst() : actions.first
        }
    }

    /// The index of the first argument whose matcher rejects `parameters`, or `nil` if they all accept it. Like
    /// matching, it stops at that argument, so a capturing matcher after it doesn't run.
    func firstMismatch(in parameters: IN) -> Int? {
        parameterMatchers.firstIndex { !$0.matches(parameters) }
    }
}

/// A stub of a class mock's member, which can also call the real implementation.
public final class ClassConcreteStub<IN, OUT, ERROR: Error, IMPL>: ConcreteStub<IN, OUT, ERROR, IMPL> { }
