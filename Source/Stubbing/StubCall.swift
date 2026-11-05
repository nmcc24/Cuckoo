import Foundation

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
        let string = String(describing: parameters)
        if (string.range(of: ",") != nil && string.hasPrefix("(")) || string == "()" {
            return string
        } else {
            // If only one parameter add brackets and quotes
            let wrappedParameter = String(describing: (parameters, 0))            
            return wrappedParameter[..<wrappedParameter.index(wrappedParameter.endIndex, offsetBy: -4)] + ")"
        }
    }
    
    /// Records a call to `method` with `parameters`.
    public init(method: String, parameters: (IN)) {
        self.method = method
        self.parameters = parameters
    }
}
