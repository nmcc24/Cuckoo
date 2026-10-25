public protocol ToBeStubbedThrowingProperty {
    associatedtype GetterType: StubThrowingFunction

    var get: GetterType { get }
}

public struct ProtocolToBeStubbedThrowingProperty<MOCK: ProtocolMock, T, GET, SHARING>: ToBeStubbedThrowingProperty {
    private let manager: MockManager
    private let name: String

    public var get: ProtocolStubThrowingFunction<Void, T, any Error, GET, SHARING> {
        ProtocolStubThrowingFunction(
            stub: manager.createStub(
                for: MOCK.self,
                method: getterName(name),
                parameterMatchers: []
            )
        )
    }

    public init(manager: MockManager, name: String) {
        self.manager = manager
        self.name = name
    }
}

public struct ClassToBeStubbedThrowingProperty<MOCK: ClassMock, T, GET, SHARING>: ToBeStubbedThrowingProperty {
    private let manager: MockManager
    private let name: String

    public var get: ClassStubThrowingFunction<Void, T, any Error, GET, SHARING> {
        ClassStubThrowingFunction(
            stub: manager.createStub(
                for: MOCK.self,
                method: getterName(name),
                parameterMatchers: []
            )
        )
    }

    public init(manager: MockManager, name: String) {
        self.manager = manager
        self.name = name
    }
}
