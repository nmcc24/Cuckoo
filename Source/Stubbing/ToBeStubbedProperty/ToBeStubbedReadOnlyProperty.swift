/// The stubbing handle of a read-only property.
public protocol ToBeStubbedReadOnlyProperty {
    /// The getter's stubbing handle type.
    associatedtype GetterType: StubFunction

    /// The getter's stubbing handle.
    var get: GetterType { get }
}

/// The stubbing handle of a protocol mock's read-only property: `when(stub.name.get)`.
public struct ProtocolToBeStubbedReadOnlyProperty<MOCK: ProtocolMock, T, GET, SHARING>: ToBeStubbedReadOnlyProperty {
    private let manager: MockManager
    private let name: String
    
    /// The getter's stubbing handle: `when(stub.name.get).thenReturn(…)`.
    public var get: ProtocolStubFunction<Void, T, GET, SHARING> {
        ProtocolStubFunction(
            stub: manager.createStub(
                for: MOCK.self,
                method: getterName(name),
                parameterMatchers: []
            )
        )
    }
    
    /// Creates the handle of the property `name`. The generated stubbing proxy creates it.
    public init(manager: MockManager, name: String) {
        self.manager = manager
        self.name = name
    }
}

/// The stubbing handle of a class mock's read-only property: `when(stub.name.get)`.
public struct ClassToBeStubbedReadOnlyProperty<MOCK: ClassMock, T, GET, SHARING>: ToBeStubbedReadOnlyProperty {
    private let manager: MockManager
    private let name: String

    /// The getter's stubbing handle: `when(stub.name.get).thenReturn(…)`.
    public var get: ClassStubFunction<Void, T, GET, SHARING> {
        ClassStubFunction(
            stub: manager.createStub(
                for: MOCK.self,
                method: getterName(name),
                parameterMatchers: []
            )
        )
    }

    /// Creates the handle of the property `name`. The generated stubbing proxy creates it.
    public init(manager: MockManager, name: String) {
        self.manager = manager
        self.name = name
    }
}
