/// The stubbing proxy's handle on a member that returns nothing and throws, which `when(…)` takes.
public protocol StubNoReturnThrowingFunction: StubFunctionThenTrait, StubFunctionThenDoNothingTrait, StubFunctionThenThrowTrait {
}

/// The handle on a protocol mock's member that returns nothing and throws.
public struct ProtocolStubNoReturnThrowingFunction<IN, ERROR: Error, IMPL, SHARING>: StubNoReturnThrowingFunction {
    /// What `thenReturn` accepts, from the mocked type.
    public typealias Sharing = SHARING
    /// The stub the `then…` calls add answers to.
    public let stub: ConcreteStub<IN, Void, ERROR, IMPL>

    /// Wraps `stub`. The generated stubbing proxy creates it.
    public init(stub: ConcreteStub<IN, Void, ERROR, IMPL>) {
        self.stub = stub
    }
}

/// The handle on a class mock's member that returns nothing and throws, which can also call the real implementation.
public struct ClassStubNoReturnThrowingFunction<IN, ERROR: Error, IMPL, SHARING>: StubNoReturnThrowingFunction, StubFunctionThenCallRealImplementationTrait {
    /// What `thenReturn` accepts, from the mocked type.
    public typealias Sharing = SHARING
    /// The stub the `then…` calls add answers to.
    public let stub: ConcreteStub<IN, Void, ERROR, IMPL>

    /// Wraps `stub`. The generated stubbing proxy creates it.
    public init(stub: ClassConcreteStub<IN, Void, ERROR, IMPL>) {
        self.stub = stub
    }
}
