/// A stubbing handle that can run a closure for matching calls.
public protocol StubFunctionThenTrait: BaseStubFunctionTrait {
    /// Runs `implementation` for matching calls, with the call's arguments, and returns or throws what it does. It runs in the mock's isolation: on its global actor for a
    /// `@MainActor` or global-actor mock, and on the mock for an actor mock.
    func then(_ implementation: ImplementationType) -> Self
}

public extension StubFunctionThenTrait {
    /// Runs `implementation` for matching calls, with the call's arguments, and returns or throws what it does.
    /// It runs in the mock's isolation.
    @discardableResult
    func then(_ implementation: ImplementationType) -> Self {
        stub.appendAction(.callImplementation(implementation))
        return self
    }
}
