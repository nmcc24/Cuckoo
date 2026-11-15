/// A call a mock recorded.
public protocol StubCall {
    /// The called member, as failure messages name it.
    var method: String { get }
    /// The call's arguments, as failure messages show them.
    var parametersAsString: String { get }
}

/// A recorded call to a member whose arguments are `IN`.
public struct ConcreteStubCall<IN>: StubCall {
    /// The called member, as failure messages name it.
    public let method: String
    /// The call's arguments, as a tuple for several parameters.
    public let parameters: (IN)

    /// The call's arguments in parentheses, as failure messages show them.
    public var parametersAsString: String {
        // Several parameters, or none, are a tuple, which describes its elements as a debugger would: quoted strings.
        // A string that only looks like a tuple, such as "(a, b)", is one parameter.
        if Mirror(reflecting: parameters).displayStyle == .tuple {
            return String(describing: parameters)
        }
        // One parameter: described as a tuple's element, so a string gets its quotes, in parentheses.
        let wrappedParameter = String(describing: (parameters, 0))
        return wrappedParameter.dropLast(4) + ")"
    }
    
    /// Records a call to `method` with `parameters`.
    public init(method: String, parameters: (IN)) {
        self.method = method
        self.parameters = parameters
    }
}
