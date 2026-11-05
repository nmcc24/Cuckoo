/// The stubbing proxy's handle on a member that returns a value, which `when(…)` takes.
public protocol StubFunction: StubFunctionThenTrait, StubFunctionThenReturnTrait {
}

/// The handle on a protocol mock's member that returns a value.
public struct ProtocolStubFunction<IN, OUT, IMPL, SHARING>: StubFunction {
    /// What `thenReturn` accepts, from the mocked type.
    public typealias Sharing = SHARING
    /// The stub the `then…` calls add answers to.
    public let stub: ConcreteStub<IN, OUT, Never, IMPL>

    /// Wraps `stub`. The generated stubbing proxy creates it.
    public init(stub: ConcreteStub<IN, OUT, Never, IMPL>) {
        self.stub = stub
    }
}

/// The handle on a class mock's member that returns a value, which can also call the real implementation.
public struct ClassStubFunction<IN, OUT, IMPL, SHARING>: StubFunction, StubFunctionThenCallRealImplementationTrait {
    /// What `thenReturn` accepts, from the mocked type.
    public typealias Sharing = SHARING
    /// The stub the `then…` calls add answers to.
    public let stub: ConcreteStub<IN, OUT, Never, IMPL>

    /// Wraps `stub`. The generated stubbing proxy creates it.
    public init(stub: ClassConcreteStub<IN, OUT, Never, IMPL>) {
        self.stub = stub
    }
}
