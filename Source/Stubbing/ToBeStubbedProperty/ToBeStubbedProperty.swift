/// The stubbing handle of a read-write property.
public protocol ToBeStubbedProperty: ToBeStubbedReadOnlyProperty where GetterType.OutputType == SetterType.InputType {
    /// The setter's stubbing handle type.
    associatedtype SetterType: StubNoReturnFunction

    /// The setter's stubbing handle, for assignments whose new value matches `matcher`.
    func set<M: Matchable>(_ matcher: M) -> SetterType where M.MatchedType == SetterType.InputType
}

/// The stubbing handle of a protocol mock's read-write property: `when(stub.name.get)` and `when(stub.name.set(…))`.
public struct ProtocolToBeStubbedProperty<MOCK: ProtocolMock, T, GET, SET, SHARING>: ToBeStubbedProperty {
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
    
    /// The setter's stubbing handle, for assignments whose new value matches `matcher`.
    public func set<M: Matchable>(_ matcher: M) -> ProtocolStubNoReturnFunction<T, SET, SHARING> where M.MatchedType == T {
        ProtocolStubNoReturnFunction(
            stub: manager.createStub(
                for: MOCK.self,
                method: setterName(name),
                parameterMatchers: [matcher.matcher]
            )
        )
    }
    
    /// Creates the handle of the property `name`. The generated stubbing proxy creates it.
    public init(manager: MockManager, name: String) {
        self.manager = manager
        self.name = name
    }
}

/// The stubbing handle of a class mock's read-write property: `when(stub.name.get)` and `when(stub.name.set(…))`.
public struct ClassToBeStubbedProperty<MOCK: ClassMock, T, GET, SET, SHARING>: ToBeStubbedProperty {
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

    /// The setter's stubbing handle, for assignments whose new value matches `matcher`.
    public func set<M: Matchable>(_ matcher: M) -> ClassStubNoReturnFunction<T, SET, SHARING> where M.MatchedType == T {
        ClassStubNoReturnFunction(
            stub: manager.createStub(
                for: MOCK.self,
                method: setterName(name),
                parameterMatchers: [matcher.matcher]
            )
        )
    }

    /// Creates the handle of the property `name`. The generated stubbing proxy creates it.
    public init(manager: MockManager, name: String) {
        self.manager = manager
        self.name = name
    }
}

/// The stubbing handle of a optional read-write property.
public protocol ToBeStubbedOptionalProperty: ToBeStubbedReadOnlyProperty where GetterType.OutputType == SetterType.InputType, SetterType.InputType == WrappedType? {
    /// The property's type without its optional.
    associatedtype WrappedType
    /// The setter's stubbing handle type.
    associatedtype SetterType: StubNoReturnFunction

    /// The setter's stubbing handle, for assignments whose new value matches `matcher`.
    func set<M: OptionalMatchable>(_ matcher: M) -> SetterType where M.OptionalMatchedType == WrappedType
}

/// The stubbing handle of a protocol mock's optional read-write property: `when(stub.name.get)` and `when(stub.name.set(…))`.
public struct ProtocolToBeStubbedOptionalProperty<MOCK: ProtocolMock, T, GET, SET, SHARING>: ToBeStubbedOptionalProperty {
    /// The property's type without its optional.
    public typealias WrappedType = T

    private let manager: MockManager
    private let name: String

    /// The getter's stubbing handle: `when(stub.name.get).thenReturn(…)`.
    public var get: ProtocolStubFunction<Void, T?, GET, SHARING> {
        ProtocolStubFunction(
            stub: manager.createStub(
                for: MOCK.self,
                method: getterName(name),
                parameterMatchers: []
            )
        )
    }

    /// The setter's stubbing handle, for assignments whose new value matches `matcher`.
    public func set<M: OptionalMatchable>(_ matcher: M) -> ProtocolStubNoReturnFunction<T?, SET, SHARING> where M.OptionalMatchedType == T {
        ProtocolStubNoReturnFunction(
            stub: manager.createStub(
                for: MOCK.self,
                method: setterName(name),
                parameterMatchers: [matcher.optionalMatcher]
            )
        )
    }

    /// Creates the handle of the property `name`. The generated stubbing proxy creates it.
    public init(manager: MockManager, name: String) {
        self.manager = manager
        self.name = name
    }
}

/// The stubbing handle of a class mock's optional read-write property: `when(stub.name.get)` and `when(stub.name.set(…))`.
public struct ClassToBeStubbedOptionalProperty<MOCK: ClassMock, T, GET, SET, SHARING>: ToBeStubbedOptionalProperty {
    /// The property's type without its optional.
    public typealias WrappedType = T

    private let manager: MockManager
    private let name: String

    /// The getter's stubbing handle: `when(stub.name.get).thenReturn(…)`.
    public var get: ClassStubFunction<Void, T?, GET, SHARING> {
        ClassStubFunction(
            stub: manager.createStub(
                for: MOCK.self,
                method: getterName(name),
                parameterMatchers: []
            )
        )
    }

    /// The setter's stubbing handle, for assignments whose new value matches `matcher`.
    public func set<M: OptionalMatchable>(_ matcher: M) -> ClassStubNoReturnFunction<T?, SET, SHARING> where M.OptionalMatchedType == T {
        ClassStubNoReturnFunction(
            stub: manager.createStub(
                for: MOCK.self,
                method: setterName(name),
                parameterMatchers: [matcher.optionalMatcher]
            )
        )
    }

    /// Creates the handle of the property `name`. The generated stubbing proxy creates it.
    public init(manager: MockManager, name: String) {
        self.manager = manager
        self.name = name
    }
}
