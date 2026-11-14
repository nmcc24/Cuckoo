/// Creates the mock of `mockedType` and stubs it before it's returned.
///
/// - Parameters:
///   - mockedType: A type conforming to ``Mocked``, which names its mock.
///   - configuration: Receives a ``MockBuilder`` and the stubbing proxy, and returns the new mock, for example
///     `{ builder, stub in when(stub.name.get).thenReturn("A"); return MockPerson() }`.
public func createMock<MOCKED: Mocked>(
    for mockedType: MOCKED.Type,
    configuration: (MockBuilder, MOCKED.MockType.Stubbing) -> MOCKED.MockType
) -> MOCKED.MockType {
    createMock(MOCKED.MockType.self, configuration: configuration)
}

/// Creates a mock and stubs it before it's returned, which a mock whose initializer calls its own members needs.
///
/// - Parameters:
///   - mockType: The generated mock's type.
///   - configuration: Receives a ``MockBuilder`` and the stubbing proxy, and returns the new mock, which picks up
///     the stubs made here. Only mocks of `mockType` created in it share them: other mocks it creates, such as the
///     new mock's arguments, are separate.
public func createMock<MOCK: Mock>(
    _ mockType: MOCK.Type,
    configuration: (MockBuilder, MOCK.Stubbing) -> MOCK
) -> MOCK {
    let manager = MockManager(hasParent: MOCK.cuckoo_hasSuperclass)

    let builder = MockBuilder(manager: manager)
    let stubbing = MOCK.Stubbing(manager: manager)
    let preconfigured = MockManager.Preconfigured(manager: manager, mockType: ObjectIdentifier(MOCK.self))
    return MockManager.$preconfigured.withValue(preconfigured) {
        configuration(builder, stubbing)
    }
}
