/// The stubbing handle of a throwing read-only property.
public protocol ToBeStubbedThrowingProperty {
    /// The getter's stubbing handle type.
    associatedtype GetterType: StubThrowingFunction

    /// The getter's stubbing handle.
    var get: GetterType { get }
}

/// The stubbing handle of a protocol mock's throwing read-only property: `when(stub.name.get)`. `ERROR` is the
/// getter's error type: `any Error`, or the type a typed-throws getter, `get throws(E)`, names.
public struct ProtocolToBeStubbedThrowingProperty<MOCK: ProtocolMock, T, ERROR: Error, GET, SHARING>: ToBeStubbedThrowingProperty {
    private let manager: MockManager
    private let name: String

    /// The getter's stubbing handle: `when(stub.name.get).thenReturn(…)`.
    public var get: ProtocolStubThrowingFunction<Void, T, ERROR, GET, SHARING> {
        ProtocolStubThrowingFunction(
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

/// The stubbing handle of a class mock's throwing read-only property: `when(stub.name.get)`. `ERROR` is the
/// getter's error type: `any Error`, or the type a typed-throws getter, `get throws(E)`, names.
public struct ClassToBeStubbedThrowingProperty<MOCK: ClassMock, T, ERROR: Error, GET, SHARING>: ToBeStubbedThrowingProperty {
    private let manager: MockManager
    private let name: String

    /// The getter's stubbing handle: `when(stub.name.get).thenReturn(…)`.
    public var get: ClassStubThrowingFunction<Void, T, ERROR, GET, SHARING> {
        ClassStubThrowingFunction(
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
