/// A class mock's stubbing handle, which can call the real implementation.
public protocol StubFunctionThenCallRealImplementationTrait: BaseStubFunctionTrait {
    /// Makes matching calls run the superclass's real implementation.
    func thenCallRealImplementation() -> Self
}

public extension StubFunctionThenCallRealImplementationTrait {
    /// Makes matching calls run the superclass's real implementation.
    @discardableResult
    func thenCallRealImplementation() -> Self {
        stub.appendAction(.callRealImplementation)
        return self
    }
}
