public protocol StubFunction: StubFunctionThenTrait, StubFunctionThenReturnTrait {
}

public struct ProtocolStubFunction<IN, OUT, IMPL, SHARING>: StubFunction {
    public typealias Sharing = SHARING
    public let stub: ConcreteStub<IN, OUT, Never, IMPL>

    public init(stub: ConcreteStub<IN, OUT, Never, IMPL>) {
        self.stub = stub
    }
}

public struct ClassStubFunction<IN, OUT, IMPL, SHARING>: StubFunction, StubFunctionThenCallRealImplementationTrait {
    public typealias Sharing = SHARING
    public let stub: ConcreteStub<IN, OUT, Never, IMPL>

    public init(stub: ClassConcreteStub<IN, OUT, Never, IMPL>) {
        self.stub = stub
    }
}
