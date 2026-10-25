public protocol StubNoReturnFunction: StubFunctionThenTrait, StubFunctionThenDoNothingTrait {
}

public struct ProtocolStubNoReturnFunction<IN, IMPL, SHARING>: StubNoReturnFunction {
    public typealias Sharing = SHARING
    public let stub: ConcreteStub<IN, Void, Never, IMPL>

    public init(stub: ConcreteStub<IN, Void, Never, IMPL>) {
        self.stub = stub
    }
}

public struct ClassStubNoReturnFunction<IN, IMPL, SHARING>: StubNoReturnFunction, StubFunctionThenCallRealImplementationTrait {
    public typealias Sharing = SHARING
    public let stub: ConcreteStub<IN, Void, Never, IMPL>

    public init(stub: ClassConcreteStub<IN, Void, Never, IMPL>) {
        self.stub = stub
    }
}
