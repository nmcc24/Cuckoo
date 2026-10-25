public protocol StubFunctionThenTrait: BaseStubFunctionTrait {
    /// Invokes `implementation` when invoked. It runs in the mock's isolation: on its global actor for a
    /// `@MainActor` or global-actor mock, and on the mock for an actor mock.
    func then(_ implementation: ImplementationType) -> Self
}

public extension StubFunctionThenTrait {
    @discardableResult
    func then(_ implementation: ImplementationType) -> Self {
        stub.appendAction(.callImplementation(implementation))
        return self
    }
}
