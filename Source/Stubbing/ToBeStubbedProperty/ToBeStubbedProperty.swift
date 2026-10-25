public protocol ToBeStubbedProperty: ToBeStubbedReadOnlyProperty where GetterType.OutputType == SetterType.InputType {
    associatedtype SetterType: StubNoReturnFunction

    func set<M: Matchable>(_ matcher: M) -> SetterType where M.MatchedType == SetterType.InputType
}

public struct ProtocolToBeStubbedProperty<MOCK: ProtocolMock, T, GET, SET, SHARING>: ToBeStubbedProperty {
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
    
    public func set<M: Matchable>(_ matcher: M) -> ProtocolStubNoReturnFunction<T, SET, SHARING> where M.MatchedType == T {
        ProtocolStubNoReturnFunction(
            stub: manager.createStub(
                for: MOCK.self,
                method: setterName(name),
                parameterMatchers: [matcher.matcher]
            )
        )
    }
    
    public init(manager: MockManager, name: String) {
        self.manager = manager
        self.name = name
    }
}

public struct ClassToBeStubbedProperty<MOCK: ClassMock, T, GET, SET, SHARING>: ToBeStubbedProperty {
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

    public func set<M: Matchable>(_ matcher: M) -> ClassStubNoReturnFunction<T, SET, SHARING> where M.MatchedType == T {
        ClassStubNoReturnFunction(
            stub: manager.createStub(
                for: MOCK.self,
                method: setterName(name),
                parameterMatchers: [matcher.matcher]
            )
        )
    }

    public init(manager: MockManager, name: String) {
        self.manager = manager
        self.name = name
    }
}

public protocol ToBeStubbedOptionalProperty: ToBeStubbedReadOnlyProperty where GetterType.OutputType == SetterType.InputType, SetterType.InputType == WrappedType? {
    associatedtype WrappedType
    associatedtype SetterType: StubNoReturnFunction

    func set<M: OptionalMatchable>(_ matcher: M) -> SetterType where M.OptionalMatchedType == WrappedType
}

public struct ProtocolToBeStubbedOptionalProperty<MOCK: ProtocolMock, T, GET, SET, SHARING>: ToBeStubbedOptionalProperty {
    public typealias WrappedType = T

    private let manager: MockManager
    private let name: String

    public var get: ProtocolStubFunction<Void, T?, GET, SHARING> {
        ProtocolStubFunction(
            stub: manager.createStub(
                for: MOCK.self,
                method: getterName(name),
                parameterMatchers: []
            )
        )
    }

    public func set<M: OptionalMatchable>(_ matcher: M) -> ProtocolStubNoReturnFunction<T?, SET, SHARING> where M.OptionalMatchedType == T {
        ProtocolStubNoReturnFunction(
            stub: manager.createStub(
                for: MOCK.self,
                method: setterName(name),
                parameterMatchers: [matcher.optionalMatcher]
            )
        )
    }

    public init(manager: MockManager, name: String) {
        self.manager = manager
        self.name = name
    }
}

public struct ClassToBeStubbedOptionalProperty<MOCK: ClassMock, T, GET, SET, SHARING>: ToBeStubbedOptionalProperty {
    public typealias WrappedType = T

    private let manager: MockManager
    private let name: String

    public var get: ClassStubFunction<Void, T?, GET, SHARING> {
        ClassStubFunction(
            stub: manager.createStub(
                for: MOCK.self,
                method: getterName(name),
                parameterMatchers: []
            )
        )
    }

    public func set<M: OptionalMatchable>(_ matcher: M) -> ClassStubNoReturnFunction<T?, SET, SHARING> where M.OptionalMatchedType == T {
        ClassStubNoReturnFunction(
            stub: manager.createStub(
                for: MOCK.self,
                method: setterName(name),
                parameterMatchers: [matcher.optionalMatcher]
            )
        )
    }

    public init(manager: MockManager, name: String) {
        self.manager = manager
        self.name = name
    }
}
