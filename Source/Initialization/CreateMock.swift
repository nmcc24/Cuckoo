/// Creates a class mock and stubs it before its initializer runs, which a mock of a class whose initializer calls
/// its own members needs. A protocol mock's initializer calls none: create it and stub it,
/// `let greeter = MockGreeter(); stub(greeter) { … }`.
///
/// - Parameters:
///   - mockType: The generated class mock's type.
///   - configuration: Receives a ``MockBuilder`` and the stubbing proxy, and returns the new mock, which picks up
///     the stubs made here. Only mocks of `mockType` created while it runs share them: other mocks it creates, such
///     as the new mock's arguments, and mocks a task it starts creates after it returns, are separate.
public func createMock<MOCK: ClassMock>(
    _ mockType: MOCK.Type,
    configuration: (MockBuilder, MOCK.CuckooStubbing) -> MOCK
) -> MOCK {
    let manager = MockManager(hasParent: true)

    let builder = MockBuilder(manager: manager)
    let stubbing = MOCK.CuckooStubbing(manager: manager)
    let preconfigured = MockManager.Preconfigured(manager: manager, mockType: ObjectIdentifier(MOCK.self))
    defer { preconfigured.isOpen.withLock { $0 = false } }
    return MockManager.$preconfigured.withValue(preconfigured) {
        configuration(builder, stubbing)
    }
}
