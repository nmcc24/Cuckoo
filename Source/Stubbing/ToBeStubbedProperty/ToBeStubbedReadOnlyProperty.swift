public protocol ToBeStubbedReadOnlyProperty {
    associatedtype GetterType: StubFunction

    var get: GetterType { get }
}

public struct ProtocolToBeStubbedReadOnlyProperty<MOCK: ProtocolMock, T, GET, SHARING>: ToBeStubbedReadOnlyProperty {
    private let manager: MockManager
    private let name: String
    
    public var get: ProtocolStubFunction<Void, T, GET, SHARING> {
        ProtocolStubFunction(
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

public struct ClassToBeStubbedReadOnlyProperty<MOCK: ClassMock, T, GET, SHARING>: ToBeStubbedReadOnlyProperty {
    private let manager: MockManager
    private let name: String

    public var get: ClassStubFunction<Void, T, GET, SHARING> {
        ClassStubFunction(
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
