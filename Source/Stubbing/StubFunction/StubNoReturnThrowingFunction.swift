public protocol StubNoReturnThrowingFunction: StubFunctionThenTrait, StubFunctionThenDoNothingTrait, StubFunctionThenThrowTrait {
}

public struct ProtocolStubNoReturnThrowingFunction<IN, ERROR: Error, IMPL, SHARING>: StubNoReturnThrowingFunction {
    public typealias Sharing = SHARING
    public let stub: ConcreteStub<IN, Void, ERROR, IMPL>

    public init(stub: ConcreteStub<IN, Void, ERROR, IMPL>) {
        self.stub = stub
    }
}

public struct ClassStubNoReturnThrowingFunction<IN, ERROR: Error, IMPL, SHARING>: StubNoReturnThrowingFunction, StubFunctionThenCallRealImplementationTrait {
    public typealias Sharing = SHARING
    public let stub: ConcreteStub<IN, Void, ERROR, IMPL>

    public init(stub: ClassConcreteStub<IN, Void, ERROR, IMPL>) {
        self.stub = stub
    }
}
