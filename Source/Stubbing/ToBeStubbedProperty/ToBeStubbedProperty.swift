/// The stubbing handle of a read-write property.
public protocol ToBeStubbedProperty: ToBeStubbedReadOnlyProperty where GetterType.OutputType == SetterType.InputType {
    /// The setter's stubbing handle type.
    associatedtype SetterType: StubNoReturnFunction
}

/// The stubbing handle of a protocol mock's read-write property: `when(stub.name.get)` and `when(stub.name.set(…))`.
public struct ProtocolToBeStubbedProperty<MOCK: ProtocolMock, T, GET, SET, SHARING>: ToBeStubbedProperty {
    /// The setter's stubbing handle type.
    public typealias SetterType = ProtocolStubNoReturnFunction<T, SET, SHARING>

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

extension ProtocolToBeStubbedProperty where SHARING == StubSharing.Confined {
    /// The setter's stubbing handle, for assignments whose new value matches `matcher`.
    public func set<M: _Matchable>(_ matcher: M) -> ProtocolStubNoReturnFunction<T, SET, SHARING> where M.MatchedType == T {
        ProtocolStubNoReturnFunction(
            stub: manager.createStub(
                for: MOCK.self,
                method: setterName(name),
                parameterMatchers: [matcher.matcher]
            )
        )
    }
}

extension ProtocolToBeStubbedProperty where SHARING == StubSharing.Isolated {
    /// The setter's stubbing handle, for assignments whose new value matches `matcher`.
    public func set<M: _Matchable>(_ matcher: M) -> ProtocolStubNoReturnFunction<T, SET, SHARING> where M.MatchedType == T {
        ProtocolStubNoReturnFunction(
            stub: manager.createStub(
                for: MOCK.self,
                method: setterName(name),
                parameterMatchers: [matcher.matcher]
            )
        )
    }
}

extension ProtocolToBeStubbedProperty where SHARING == StubSharing.Shared {
    /// The setter's stubbing handle, for assignments whose new value matches `matcher`. Calls can come from
    /// any task, so `matcher` must be `Sendable`.
    public func set<M: _SendableMatchable>(_ matcher: M) -> ProtocolStubNoReturnFunction<T, SET, SHARING> where M.MatchedType == T {
        ProtocolStubNoReturnFunction(
            stub: manager.createStub(
                for: MOCK.self,
                method: setterName(name),
                parameterMatchers: [matcher.matcher]
            )
        )
    }
}

/// The stubbing handle of a class mock's read-write property: `when(stub.name.get)` and `when(stub.name.set(…))`.
public struct ClassToBeStubbedProperty<MOCK: ClassMock, T, GET, SET, SHARING>: ToBeStubbedProperty {
    /// The setter's stubbing handle type.
    public typealias SetterType = ClassStubNoReturnFunction<T, SET, SHARING>

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

/// The stubbing handle of a optional read-write property.
public protocol ToBeStubbedOptionalProperty: ToBeStubbedReadOnlyProperty where GetterType.OutputType == SetterType.InputType, SetterType.InputType == WrappedType? {
    /// The property's type without its optional.
    associatedtype WrappedType
    /// The setter's stubbing handle type.
    associatedtype SetterType: StubNoReturnFunction
}

extension ClassToBeStubbedProperty where SHARING == StubSharing.Confined {
    /// The setter's stubbing handle, for assignments whose new value matches `matcher`.
    public func set<M: _Matchable>(_ matcher: M) -> ClassStubNoReturnFunction<T, SET, SHARING> where M.MatchedType == T {
        ClassStubNoReturnFunction(
            stub: manager.createStub(
                for: MOCK.self,
                method: setterName(name),
                parameterMatchers: [matcher.matcher]
            )
        )
    }
}

extension ClassToBeStubbedProperty where SHARING == StubSharing.Isolated {
    /// The setter's stubbing handle, for assignments whose new value matches `matcher`.
    public func set<M: _Matchable>(_ matcher: M) -> ClassStubNoReturnFunction<T, SET, SHARING> where M.MatchedType == T {
        ClassStubNoReturnFunction(
            stub: manager.createStub(
                for: MOCK.self,
                method: setterName(name),
                parameterMatchers: [matcher.matcher]
            )
        )
    }
}

extension ClassToBeStubbedProperty where SHARING == StubSharing.Shared {
    /// The setter's stubbing handle, for assignments whose new value matches `matcher`. Calls can come from
    /// any task, so `matcher` must be `Sendable`.
    public func set<M: _SendableMatchable>(_ matcher: M) -> ClassStubNoReturnFunction<T, SET, SHARING> where M.MatchedType == T {
        ClassStubNoReturnFunction(
            stub: manager.createStub(
                for: MOCK.self,
                method: setterName(name),
                parameterMatchers: [matcher.matcher]
            )
        )
    }
}

/// The stubbing handle of a protocol mock's optional read-write property: `when(stub.name.get)` and `when(stub.name.set(…))`.
public struct ProtocolToBeStubbedOptionalProperty<MOCK: ProtocolMock, T, GET, SET, SHARING>: ToBeStubbedOptionalProperty {
    /// The setter's stubbing handle type.
    public typealias SetterType = ProtocolStubNoReturnFunction<T?, SET, SHARING>

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


    /// Creates the handle of the property `name`. The generated stubbing proxy creates it.
    public init(manager: MockManager, name: String) {
        self.manager = manager
        self.name = name
    }
}

extension ProtocolToBeStubbedOptionalProperty where SHARING == StubSharing.Confined {
    /// The setter's stubbing handle, for assignments whose new value matches `matcher`.
    public func set<M: _OptionalMatchable>(_ matcher: M) -> ProtocolStubNoReturnFunction<T?, SET, SHARING> where M.OptionalMatchedType == T {
        ProtocolStubNoReturnFunction(
            stub: manager.createStub(
                for: MOCK.self,
                method: setterName(name),
                parameterMatchers: [matcher.optionalMatcher]
            )
        )
    }
}

extension ProtocolToBeStubbedOptionalProperty where SHARING == StubSharing.Isolated {
    /// The setter's stubbing handle, for assignments whose new value matches `matcher`.
    public func set<M: _OptionalMatchable>(_ matcher: M) -> ProtocolStubNoReturnFunction<T?, SET, SHARING> where M.OptionalMatchedType == T {
        ProtocolStubNoReturnFunction(
            stub: manager.createStub(
                for: MOCK.self,
                method: setterName(name),
                parameterMatchers: [matcher.optionalMatcher]
            )
        )
    }
}

extension ProtocolToBeStubbedOptionalProperty where SHARING == StubSharing.Shared {
    /// The setter's stubbing handle, for assignments whose new value matches `matcher`. Calls can come from
    /// any task, so `matcher` must be `Sendable`.
    public func set<M: _SendableOptionalMatchable>(_ matcher: M) -> ProtocolStubNoReturnFunction<T?, SET, SHARING> where M.OptionalMatchedType == T {
        ProtocolStubNoReturnFunction(
            stub: manager.createStub(
                for: MOCK.self,
                method: setterName(name),
                parameterMatchers: [matcher.optionalMatcher]
            )
        )
    }
}

/// The stubbing handle of a class mock's optional read-write property: `when(stub.name.get)` and `when(stub.name.set(…))`.
public struct ClassToBeStubbedOptionalProperty<MOCK: ClassMock, T, GET, SET, SHARING>: ToBeStubbedOptionalProperty {
    /// The setter's stubbing handle type.
    public typealias SetterType = ClassStubNoReturnFunction<T?, SET, SHARING>

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


    /// Creates the handle of the property `name`. The generated stubbing proxy creates it.
    public init(manager: MockManager, name: String) {
        self.manager = manager
        self.name = name
    }
}

extension ClassToBeStubbedOptionalProperty where SHARING == StubSharing.Confined {
    /// The setter's stubbing handle, for assignments whose new value matches `matcher`.
    public func set<M: _OptionalMatchable>(_ matcher: M) -> ClassStubNoReturnFunction<T?, SET, SHARING> where M.OptionalMatchedType == T {
        ClassStubNoReturnFunction(
            stub: manager.createStub(
                for: MOCK.self,
                method: setterName(name),
                parameterMatchers: [matcher.optionalMatcher]
            )
        )
    }
}

extension ClassToBeStubbedOptionalProperty where SHARING == StubSharing.Isolated {
    /// The setter's stubbing handle, for assignments whose new value matches `matcher`.
    public func set<M: _OptionalMatchable>(_ matcher: M) -> ClassStubNoReturnFunction<T?, SET, SHARING> where M.OptionalMatchedType == T {
        ClassStubNoReturnFunction(
            stub: manager.createStub(
                for: MOCK.self,
                method: setterName(name),
                parameterMatchers: [matcher.optionalMatcher]
            )
        )
    }
}

extension ClassToBeStubbedOptionalProperty where SHARING == StubSharing.Shared {
    /// The setter's stubbing handle, for assignments whose new value matches `matcher`. Calls can come from
    /// any task, so `matcher` must be `Sendable`.
    public func set<M: _SendableOptionalMatchable>(_ matcher: M) -> ClassStubNoReturnFunction<T?, SET, SHARING> where M.OptionalMatchedType == T {
        ClassStubNoReturnFunction(
            stub: manager.createStub(
                for: MOCK.self,
                method: setterName(name),
                parameterMatchers: [matcher.optionalMatcher]
            )
        )
    }
}
