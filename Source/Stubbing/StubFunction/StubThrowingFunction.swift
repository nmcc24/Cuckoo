public protocol StubThrowingFunction: StubFunctionThenTrait, StubFunctionThenReturnTrait, StubFunctionThenThrowTrait {
}

public struct ProtocolStubThrowingFunction<IN, OUT, ERROR: Error, IMPL, SHARING>: StubThrowingFunction {
    public typealias Sharing = SHARING
    public let stub: ConcreteStub<IN, OUT, ERROR, IMPL>

    public init(stub: ConcreteStub<IN, OUT, ERROR, IMPL>) {
        self.stub = stub
    }
}

public struct ClassStubThrowingFunction<IN, OUT, ERROR: Error, IMPL, SHARING>: StubThrowingFunction, StubFunctionThenCallRealImplementationTrait {
    public typealias Sharing = SHARING
    public let stub: ConcreteStub<IN, OUT, ERROR, IMPL>

    public init(stub: ClassConcreteStub<IN, OUT, ERROR, IMPL>) {
        self.stub = stub
    }
}
