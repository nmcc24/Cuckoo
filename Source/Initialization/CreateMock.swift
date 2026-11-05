import Foundation

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
///     the stubs made here.
public func createMock<MOCK: Mock>(
    _ mockType: MOCK.Type,
    configuration: (MockBuilder, MOCK.Stubbing) -> MOCK
) -> MOCK {
    let manager = MockManager(hasParent: MOCK.cuckoo_hasSuperclass)

    let builder = MockBuilder(manager: manager)
    let stubbing = MOCK.Stubbing(manager: manager)
    return MockManager.$preconfiguredManager.withValue(manager) {
        configuration(builder, stubbing)
    }
}
