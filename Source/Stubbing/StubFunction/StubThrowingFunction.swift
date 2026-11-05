/// The stubbing proxy's handle on a member that returns a value and throws, which `when(…)` takes.
public protocol StubThrowingFunction: StubFunctionThenTrait, StubFunctionThenReturnTrait, StubFunctionThenThrowTrait {
}

/// The handle on a protocol mock's member that returns a value and throws.
public struct ProtocolStubThrowingFunction<IN, OUT, ERROR: Error, IMPL, SHARING>: StubThrowingFunction {
    /// What `thenReturn` accepts, from the mocked type.
    public typealias Sharing = SHARING
    /// The stub the `then…` calls add answers to.
    public let stub: ConcreteStub<IN, OUT, ERROR, IMPL>

    /// Wraps `stub`. The generated stubbing proxy creates it.
    public init(stub: ConcreteStub<IN, OUT, ERROR, IMPL>) {
        self.stub = stub
    }
}

/// The handle on a class mock's member that returns a value and throws, which can also call the real implementation.
public struct ClassStubThrowingFunction<IN, OUT, ERROR: Error, IMPL, SHARING>: StubThrowingFunction, StubFunctionThenCallRealImplementationTrait {
    /// What `thenReturn` accepts, from the mocked type.
    public typealias Sharing = SHARING
    /// The stub the `then…` calls add answers to.
    public let stub: ConcreteStub<IN, OUT, ERROR, IMPL>

    /// Wraps `stub`. The generated stubbing proxy creates it.
    public init(stub: ClassConcreteStub<IN, OUT, ERROR, IMPL>) {
        self.stub = stub
    }
}
