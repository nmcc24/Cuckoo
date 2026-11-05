/// The stubbing proxy's handle on a member that returns nothing, which `when(…)` takes.
public protocol StubNoReturnFunction: StubFunctionThenTrait, StubFunctionThenDoNothingTrait {
}

/// The handle on a protocol mock's member that returns nothing.
public struct ProtocolStubNoReturnFunction<IN, IMPL, SHARING>: StubNoReturnFunction {
    /// What `thenReturn` accepts, from the mocked type.
    public typealias Sharing = SHARING
    /// The stub the `then…` calls add answers to.
    public let stub: ConcreteStub<IN, Void, Never, IMPL>

    /// Wraps `stub`. The generated stubbing proxy creates it.
    public init(stub: ConcreteStub<IN, Void, Never, IMPL>) {
        self.stub = stub
    }
}

/// The handle on a class mock's member that returns nothing, which can also call the real implementation.
public struct ClassStubNoReturnFunction<IN, IMPL, SHARING>: StubNoReturnFunction, StubFunctionThenCallRealImplementationTrait {
    /// What `thenReturn` accepts, from the mocked type.
    public typealias Sharing = SHARING
    /// The stub the `then…` calls add answers to.
    public let stub: ConcreteStub<IN, Void, Never, IMPL>

    /// Wraps `stub`. The generated stubbing proxy creates it.
    public init(stub: ClassConcreteStub<IN, Void, Never, IMPL>) {
        self.stub = stub
    }
}
