#if canImport(Testing)
import Testing
#endif
#if canImport(XCTest)
import XCTest
#endif

public final class MockManager: Sendable {
    nonisolated(unsafe) public static var fail: ((message: String, sourceLocation: SourceLocation)) -> Void = { arg in
        let (message, sourceLocation) = arg
        // Report to the framework running the current test only. Swift Testing flags an
        // `XCTFail` inside its tests, and XCTest doesn't see Swift Testing issues.
        #if canImport(Testing)
        if Test.current != nil {
            Issue.record(
                Comment(rawValue: message),
                sourceLocation: Testing.SourceLocation(
                    fileID: sourceLocation.fileID,
                    filePath: sourceLocation.filePath,
                    line: sourceLocation.line,
                    column: sourceLocation.column
                )
            )
            return
        }
        #endif
        #if canImport(XCTest)
        XCTFail(message, file: sourceLocation.file, line: UInt(sourceLocation.line))
        #else
        print("\(Self.self).fail:", message, sourceLocation)
        #endif
    }

    private struct RecordedCall {
        let id: Int
        let call: StubCall
    }

    private struct State {
        /// Newest first, so a later stub overrides an earlier one with the same matchers.
        var stubs: [Stub] = []
        var calls: [RecordedCall] = []
        var unverifiedCallIDs: Set<Int> = []
        var nextCallID = 0
        // TODO Add either enum or OptionSet for these behavior modifiers and add proper validation
        var isSuperclassSpyEnabled = false
        var isDefaultImplementationEnabled = false
    }

    /// What a call resolves to once it has been recorded.
    private enum Resolution<IN, OUT, ERROR: Error> {
        case stubbed(StubAction<IN, OUT, ERROR>)
        case superclass
        case defaultImplementation
    }

    // All mutable state sits behind one lock. User code (matchers, stub implementations, the superclass and
    // default implementations) always runs outside it, so it may call back into the mock.
    private let state = Locked(State())
    private let hasParent: Bool

    public init(hasParent: Bool) {
        self.hasParent = hasParent
    }

    /// Records the call and decides how to answer it. Crashes if the call can't be answered.
    private func resolve<IN, OUT, ERROR>(
        _ method: String,
        parameters: IN,
        escapingParameters: IN,
        as _: (OUT, ERROR).Type
    ) -> Resolution<IN, OUT, ERROR> {
        let call = ConcreteStubCall(method: method, parameters: escapingParameters)
        let (stubs, isSuperclassSpyEnabled, isDefaultImplementationEnabled) = state.withLock { state in
            let id = state.nextCallID
            state.nextCallID += 1
            state.calls.append(RecordedCall(id: id, call: call))
            state.unverifiedCallIDs.insert(id)
            return (state.stubs, state.isSuperclassSpyEnabled, state.isDefaultImplementationEnabled)
        }

        let stub = stubs.lazy
            .filter { $0.method == method }
            .compactMap { $0 as? ConcreteStub<IN, OUT, ERROR> }
            .first { $0.matches(parameters) }

        if let stub {
            guard let action = stub.nextAction() else {
                failAndCrash("Stubbing of method `\(method)` using parameters \(parameters) wasn't finished (missing thenReturn()).")
            }
            if case .callRealImplementation = action {
                guard hasParent else {
                    failAndCrash("No real implementation found for method `\(method)`. This is probably caused by stubbed object being a mock of a protocol.")
                }
                return .superclass
            }
            return .stubbed(action)
        } else if isSuperclassSpyEnabled {
            return .superclass
        } else if isDefaultImplementationEnabled {
            return .defaultImplementation
        } else {
            failAndCrash("No stub for method `\(method)` using parameters \(parameters).")
        }
    }

    private func callInternal<IN, OUT>(_ method: String, parameters: IN, escapingParameters: IN, superclassCall: () -> OUT, defaultCall: () -> OUT) -> OUT {
        return callRethrowsInternal(method, parameters: parameters, escapingParameters: escapingParameters, superclassCall: superclassCall, defaultCall: defaultCall)
    }
    
    private nonisolated(nonsending) func callInternal<IN, OUT>(_ method: String, parameters: IN, escapingParameters: IN, superclassCall: () async -> OUT, defaultCall: () async -> OUT) async -> OUT {
        return await callRethrowsInternal(method, parameters: parameters, escapingParameters: escapingParameters, superclassCall: superclassCall, defaultCall: defaultCall)
    }
    
    private func callRethrowsInternal<IN, OUT, ERROR>(_ method: String, parameters: IN, escapingParameters: IN, superclassCall: () throws(ERROR) -> OUT, defaultCall: () throws(ERROR) -> OUT) rethrows -> OUT {
        switch resolve(method, parameters: parameters, escapingParameters: escapingParameters, as: (OUT, ERROR).self) {
        case .stubbed(.callImplementation(let implementation)):
            return try DispatchQueue(label: "No-care?").sync(execute: {
                return try implementation(parameters)
            })
        case .stubbed(.returnValue(let value)):
            return value
        case .stubbed(.throwError(let error)):
            return try DispatchQueue(label: "No-care?").sync(execute: {
                throw error
            })
        case .stubbed(.callRealImplementation), .superclass:
            return try superclassCall()
        case .defaultImplementation:
            return try defaultCall()
        }
    }
    
    private nonisolated(nonsending) func callRethrowsInternal<IN, OUT, ERROR>(_ method: String, parameters: IN, escapingParameters: IN, superclassCall: () async throws(ERROR) -> OUT, defaultCall: () async throws(ERROR) -> OUT) async rethrows -> OUT {
        switch resolve(method, parameters: parameters, escapingParameters: escapingParameters, as: (OUT, ERROR).self) {
        case .stubbed(.callImplementation(let implementation)):
            return try DispatchQueue(label: "No-care?").sync(execute: {
                return try implementation(parameters)
            })
        case .stubbed(.returnValue(let value)):
            return value
        case .stubbed(.throwError(let error)):
            return try DispatchQueue(label: "No-care?").sync(execute: {
                throw error
            })
        case .stubbed(.callRealImplementation), .superclass:
            return try await superclassCall()
        case .defaultImplementation:
            return try await defaultCall()
        }
    }
    
    private func callThrowsInternal<IN, OUT, ERROR>(_ method: String, parameters: IN, escapingParameters: IN, superclassCall: () throws(ERROR) -> OUT, defaultCall: () throws(ERROR) -> OUT) throws(ERROR) -> OUT {
        switch resolve(method, parameters: parameters, escapingParameters: escapingParameters, as: (OUT, ERROR).self) {
        case .stubbed(.callImplementation(let implementation)):
            return try implementation(parameters)
        case .stubbed(.returnValue(let value)):
            return value
        case .stubbed(.throwError(let error)):
            throw error
        case .stubbed(.callRealImplementation), .superclass:
            return try superclassCall()
        case .defaultImplementation:
            return try defaultCall()
        }
    }
    
    private nonisolated(nonsending) func callThrowsInternal<IN, OUT, ERROR>(_ method: String, parameters: IN, escapingParameters: IN, superclassCall: () async throws(ERROR) -> OUT, defaultCall: () async throws(ERROR) -> OUT) async throws(ERROR) -> OUT {
        switch resolve(method, parameters: parameters, escapingParameters: escapingParameters, as: (OUT, ERROR).self) {
        case .stubbed(.callImplementation(let implementation)):
            return try implementation(parameters)
        case .stubbed(.returnValue(let value)):
            return value
        case .stubbed(.throwError(let error)):
            throw error
        case .stubbed(.callRealImplementation), .superclass:
            return try await superclassCall()
        case .defaultImplementation:
            return try await defaultCall()
        }
    }
    
    public func createStub<MOCK: ClassMock, IN, OUT, ERROR>(for _: MOCK.Type, method: String, parameterMatchers: [ParameterMatcher<IN>]) -> ClassConcreteStub<IN, OUT, ERROR> {
        let stub = ClassConcreteStub<IN, OUT, ERROR>(method: method, parameterMatchers: parameterMatchers)
        state.withLock { $0.stubs.insert(stub, at: 0) }
        return stub
    }

    public func createStub<MOCK: ProtocolMock, IN, OUT, ERROR>(for _: MOCK.Type, method: String, parameterMatchers: [ParameterMatcher<IN>]) -> ConcreteStub<IN, OUT, ERROR> {
        let stub = ConcreteStub<IN, OUT, ERROR>(method: method, parameterMatchers: parameterMatchers)
        state.withLock { $0.stubs.insert(stub, at: 0) }
        return stub
    }
    
    public func verify<IN, OUT>(_ method: String, callMatcher: CallMatcher, parameterMatchers: [ParameterMatcher<IN>], sourceLocation: SourceLocation) -> __DoNotUse<IN, OUT> {
        let recordedCalls = state.withLock { $0.calls }
        let matching = recordedCalls.filter { recorded in
            guard recorded.call.method == method, let call = recorded.call as? ConcreteStubCall<IN> else { return false }
            return parameterMatchers.allSatisfy { $0.matches(call.parameters) }
        }
        state.withLock { state in
            state.unverifiedCallIDs.subtract(matching.map(\.id))
        }
        
        let calls = matching.map(\.call)
        if callMatcher.matches(calls) == false {
            let message = "Wanted \(callMatcher.name) but \(calls.count == 0 ? "not invoked" : "invoked \(calls.count) times")."
            MockManager.fail((message: message, sourceLocation: sourceLocation))
        }
        return __DoNotUse()
    }

    public func enableSuperclassSpy() {
        let error: String? = state.withLock { state in
            guard state.calls.isEmpty else {
                return "Enabling superclass spy is not allowed after stubbing! Please do that right after creating the mock."
            }
            guard !state.isDefaultImplementationEnabled else {
                return "Enabling superclass spy is not allowed with the default stub implementation enabled."
            }
            state.isSuperclassSpyEnabled = true
            return nil
        }
        if let error {
            failAndCrash(error)
        }
    }

    public func enableDefaultStubImplementation() {
        let error: String? = state.withLock { state in
            guard state.calls.isEmpty else {
                return "Enabling default stub implementation is not allowed after stubbing! Please do that right after creating the mock."
            }
            guard !state.isSuperclassSpyEnabled else {
                return "Enabling default stub implementation is not allowed with superclass spy enabled."
            }
            state.isDefaultImplementationEnabled = true
            return nil
        }
        if let error {
            failAndCrash(error)
        }
    }
    
    func reset() {
        state.withLock { state in
            state.stubs.removeAll()
            state.calls.removeAll()
            state.unverifiedCallIDs.removeAll()
        }
    }
    
    func clearStubs() {
        state.withLock { $0.stubs.removeAll() }
    }
    
    func clearInvocations() {
        state.withLock { state in
            state.calls.removeAll()
            state.unverifiedCallIDs.removeAll()
        }
    }
    
    func verifyNoMoreInteractions(_ sourceLocation: SourceLocation) {
        let unverified = state.withLock { state in
            state.calls.filter { state.unverifiedCallIDs.contains($0.id) }.map(\.call)
        }
        if unverified.isEmpty == false {
            let unverifiedCalls = unverified.map { call in
                    if let bracketIndex = call.method.range(of: "(")?.lowerBound {
                        let name = call.method[..<bracketIndex]
                        return name + call.parametersAsString
                    } else {
                        if call.method.hasSuffix("#set") {
                            return call.method + call.parametersAsString
                        } else {
                            return call.method
                        }
                    }
                }.enumerated().map { "\($0 + 1). " + $1 }.joined(separator: "\n")
            let message = "No more interactions wanted but some found:\n"
            MockManager.fail((message: message + unverifiedCalls, sourceLocation:  sourceLocation))
        }
    }

    private func failAndCrash(_ message: String, file: StaticString = #file, fileID: String = #fileID, filePath: String = #filePath, line: Int = #line, column: Int = #column) -> Never  {
        MockManager.fail((message: message, sourceLocation: (file, fileID, filePath, line, column)))

        #if _runtime(_ObjC)
        NSException(name: .internalInconsistencyException, reason: message, userInfo: nil).raise()
        #endif

        fatalError(message)
    }
}

extension MockManager {
    public static func callOrCrash<T, OUT>(_ value: T?, call: (T) throws -> OUT) rethrows -> OUT {
        guard let value = value else { return crashOnProtocolSuperclassCall() }
        return try call(value)
    }

    public static func crashOnProtocolSuperclassCall<OUT>() -> OUT {
        fatalError("This should never get called. If it does, please report an issue to Cuckoo repository.")
    }
}

extension MockManager {
    public func getter<T>(_ property: String, superclassCall: @autoclosure () -> T, defaultCall: @autoclosure () -> T) -> T {
        return call(getterName(property), parameters: Void(), escapingParameters: Void(), superclassCall: superclassCall(), defaultCall: defaultCall())
    }

    public nonisolated(nonsending) func getter<T>(_ property: String, superclassCall: @autoclosure () async -> T, defaultCall: @autoclosure () async -> T) async -> T {
        return await call(getterName(property), parameters: Void(), escapingParameters: Void(), superclassCall: await superclassCall(), defaultCall: await defaultCall())
    }

    public func setter<T>(_ property: String, value: T, superclassCall: @autoclosure () -> Void, defaultCall: @autoclosure () -> Void) {
        return call(setterName(property), parameters: value, escapingParameters: value, superclassCall: superclassCall(), defaultCall: defaultCall())
    }
}

extension MockManager {
    public func getterThrows<T>(_ property: String, superclassCall: @autoclosure () throws -> T, defaultCall: @autoclosure () throws -> T) throws -> T {
        return try callThrows(getterName(property), parameters: Void(), escapingParameters: Void(), errorType: (Error).self, superclassCall: try superclassCall(), defaultCall: try defaultCall())
    }

    public nonisolated(nonsending) func getterThrows<T>(_ property: String, superclassCall: @autoclosure () async throws -> T, defaultCall: @autoclosure () async throws -> T) async throws -> T {
        return try await callThrows(getterName(property), parameters: Void(), escapingParameters: Void(), errorType: (Error).self, superclassCall: try await superclassCall(), defaultCall: try await defaultCall())
    }
}

extension MockManager {
    public func call<IN, OUT>(_ method: String, parameters: IN, escapingParameters: IN, superclassCall: @autoclosure () -> OUT, defaultCall: @autoclosure () -> OUT) -> OUT {
        return callInternal(method, parameters: parameters, escapingParameters: escapingParameters, superclassCall: superclassCall, defaultCall: defaultCall)
    }
    
    public nonisolated(nonsending) func call<IN, OUT>(_ method: String, parameters: IN, escapingParameters: IN, superclassCall: @autoclosure () async -> OUT, defaultCall: @autoclosure () async -> OUT) async -> OUT {
        return await callInternal(method, parameters: parameters, escapingParameters: escapingParameters, superclassCall: superclassCall, defaultCall: defaultCall)
    }
}

extension MockManager {
    public func callThrows<IN, OUT, ERROR>(_ method: String, parameters: IN, escapingParameters: IN, errorType: ERROR.Type, superclassCall: @autoclosure () throws(ERROR) -> OUT, defaultCall: @autoclosure () throws(ERROR) -> OUT) throws(ERROR) -> OUT {
        return try callThrowsInternal(method, parameters: parameters, escapingParameters: escapingParameters, superclassCall: superclassCall, defaultCall: defaultCall)
    }
    
    public nonisolated(nonsending) func callThrows<IN, OUT, ERROR>(_ method: String, parameters: IN, escapingParameters: IN, errorType: ERROR.Type, superclassCall: @autoclosure () async throws(ERROR) -> OUT, defaultCall: @autoclosure () async throws(ERROR) -> OUT) async throws(ERROR) -> OUT {
        return try await callThrowsInternal(method, parameters: parameters, escapingParameters: escapingParameters, superclassCall: superclassCall, defaultCall: defaultCall)
    }
}

extension MockManager {
    public func callRethrows<IN, OUT>(_ method: String, parameters: IN, escapingParameters: IN, superclassCall: @autoclosure () throws -> OUT, defaultCall: @autoclosure () throws -> OUT) rethrows -> OUT {
        return try callRethrowsInternal(method, parameters: parameters, escapingParameters: escapingParameters, superclassCall: superclassCall, defaultCall: defaultCall)
    }
    
    public nonisolated(nonsending) func callRethrows<IN, OUT>(_ method: String, parameters: IN, escapingParameters: IN, superclassCall: @autoclosure () async throws -> OUT, defaultCall: @autoclosure () async throws -> OUT) async rethrows -> OUT {
        return try await callRethrowsInternal(method, parameters: parameters, escapingParameters: escapingParameters, superclassCall: superclassCall, defaultCall: defaultCall)
    }
}
