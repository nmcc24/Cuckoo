import Foundation

public final class MockManager: Sendable {
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
    private enum Resolution<OUT, ERROR: Error, IMPL> {
        case stubbed(StubAction<OUT, ERROR, IMPL>)
        case superclass
        case defaultImplementation
        case unstubbed
    }

    // All mutable state sits behind one lock. User code (matchers, stub implementations, the superclass and
    // default implementations) always runs outside it, so it may call back into the mock.
    private let state = Locked(State())
    private let hasParent: Bool

    public init(hasParent: Bool) {
        self.hasParent = hasParent
    }

    /// Records the call and decides how to answer it. Crashes if the call can't be answered.
    private func resolve<IN, OUT, ERROR, IMPL>(
        _ method: String,
        parameters: IN,
        escapingParameters: IN,
        as _: (OUT, ERROR, IMPL).Type
    ) -> Resolution<OUT, ERROR, IMPL> {
        let call = ConcreteStubCall(method: method, parameters: escapingParameters)
        let (stubs, isSuperclassSpyEnabled, isDefaultImplementationEnabled) = state.withLock { state in
            let id = state.nextCallID
            state.nextCallID += 1
            state.calls.append(RecordedCall(id: id, call: call))
            state.unverifiedCallIDs.insert(id)
            return (state.stubs, state.isSuperclassSpyEnabled, state.isDefaultImplementationEnabled)
        }

        // Newest stub first. A stub has no action yet while another thread is still between `when` and
        // `then…`, so it's skipped rather than treated as broken; an older stub can still answer.
        var sawUnfinishedStub = false
        let candidates = stubs.lazy
            .filter { $0.method == method }
            .compactMap { $0 as? ConcreteStub<IN, OUT, ERROR, IMPL> }
        for stub in candidates where stub.matches(parameters) {
            guard let action = stub.nextAction() else {
                sawUnfinishedStub = true
                continue
            }
            if case .callRealImplementation = action {
                guard hasParent else {
                    failAndCrash("No real implementation found for method `\(method)`. This is probably caused by stubbed object being a mock of a protocol.")
                }
                return .superclass
            }
            return .stubbed(action)
        }

        if isSuperclassSpyEnabled {
            return .superclass
        } else if isDefaultImplementationEnabled {
            return .defaultImplementation
        } else if sawUnfinishedStub {
            fail("Stubbing of method `\(method)` using parameters \(parameters) wasn't finished (missing thenReturn()).")
            return .unstubbed
        } else {
            fail("No stub for method `\(method)` using parameters \(parameters).")
            return .unstubbed
        }
    }

    /// The default value an unstubbed call returns, or a crash if its type has none.
    private func unstubbedValue<OUT>(_ method: String) -> OUT {
        guard let value = DefaultValueRegistry.unstubbedValue(for: OUT.self) else {
            failAndCrash("No stub for method `\(method)`, and its return type \(OUT.self) has no default value. Stub it, or register one with `DefaultValueRegistry` or the `.cuckoo(defaultValues:)` trait.")
        }
        return value
    }

    /// The error an unstubbed throwing call throws, if its error type can hold `CuckooError`.
    private func unstubbedError<ERROR: Error>(_ method: String, as _: ERROR.Type) -> ERROR? {
        CuckooError.unstubbedCall(method: method) as? ERROR
    }

    // The `call` variants below differ only in effects. `invoke` runs a `then` closure: the generated mock
    // passes it, so the closure runs in the mock's isolation and the manager never calls user code itself.

    private func callInternal<IN, OUT, ERROR, IMPL>(
        _ method: String,
        parameters: IN,
        escapingParameters: IN,
        invoke: (IMPL) throws(ERROR) -> OUT,
        superclassCall: () throws(ERROR) -> OUT,
        defaultCall: () throws(ERROR) -> OUT
    ) throws(ERROR) -> OUT {
        switch resolve(method, parameters: parameters, escapingParameters: escapingParameters, as: (OUT, ERROR, IMPL).self) {
        case .stubbed(.callImplementation(let implementation)):
            return try invoke(implementation)
        case .stubbed(.returnValue(let value)):
            return value
        case .stubbed(.throwError(let error)):
            throw error
        case .stubbed(.callRealImplementation), .superclass:
            return try superclassCall()
        case .defaultImplementation:
            return try defaultCall()
        case .unstubbed:
            if let error = unstubbedError(method, as: ERROR.self) {
                throw error
            }
            return unstubbedValue(method)
        }
    }

    private nonisolated(nonsending) func callInternal<IN, OUT, ERROR, IMPL>(
        _ method: String,
        parameters: IN,
        escapingParameters: IN,
        invoke: nonisolated(nonsending) (IMPL) async throws(ERROR) -> OUT,
        superclassCall: () async throws(ERROR) -> OUT,
        defaultCall: () async throws(ERROR) -> OUT
    ) async throws(ERROR) -> OUT {
        switch resolve(method, parameters: parameters, escapingParameters: escapingParameters, as: (OUT, ERROR, IMPL).self) {
        case .stubbed(.callImplementation(let implementation)):
            return try await invoke(implementation)
        case .stubbed(.returnValue(let value)):
            return value
        case .stubbed(.throwError(let error)):
            throw error
        case .stubbed(.callRealImplementation), .superclass:
            return try await superclassCall()
        case .defaultImplementation:
            return try await defaultCall()
        case .unstubbed:
            if let error = unstubbedError(method, as: ERROR.self) {
                throw error
            }
            return unstubbedValue(method)
        }
    }

    public func createStub<MOCK: ClassMock, IN, OUT, ERROR, IMPL>(for _: MOCK.Type, method: String, parameterMatchers: [ParameterMatcher<IN>]) -> ClassConcreteStub<IN, OUT, ERROR, IMPL> {
        let stub = ClassConcreteStub<IN, OUT, ERROR, IMPL>(method: method, parameterMatchers: parameterMatchers)
        state.withLock { $0.stubs.insert(stub, at: 0) }
        return stub
    }

    public func createStub<MOCK: ProtocolMock, IN, OUT, ERROR, IMPL>(for _: MOCK.Type, method: String, parameterMatchers: [ParameterMatcher<IN>]) -> ConcreteStub<IN, OUT, ERROR, IMPL> {
        let stub = ConcreteStub<IN, OUT, ERROR, IMPL>(method: method, parameterMatchers: parameterMatchers)
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
            reportFailure(message, at: sourceLocation)
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
            reportFailure(message + unverifiedCalls, at: sourceLocation)
        }
    }

    private func fail(_ message: String, file: StaticString = #file, fileID: String = #fileID, filePath: String = #filePath, line: Int = #line, column: Int = #column) {
        reportFailure(message, at: (file, fileID, filePath, line, column))
    }

    private func failAndCrash(_ message: String, file: StaticString = #file, fileID: String = #fileID, filePath: String = #filePath, line: Int = #line, column: Int = #column) -> Never  {
        reportFailure(message, at: (file, fileID, filePath, line, column))

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
    public func getter<T, IMPL>(
        _ property: String,
        invoke: (IMPL) -> T,
        superclassCall: @autoclosure () -> T,
        defaultCall: @autoclosure () -> T
    ) -> T {
        call(getterName(property), parameters: Void(), escapingParameters: Void(), invoke: invoke, superclassCall: superclassCall(), defaultCall: defaultCall())
    }

    public nonisolated(nonsending) func getter<T, IMPL>(
        _ property: String,
        invoke: nonisolated(nonsending) (IMPL) async -> T,
        superclassCall: @autoclosure () async -> T,
        defaultCall: @autoclosure () async -> T
    ) async -> T {
        await call(getterName(property), parameters: Void(), escapingParameters: Void(), invoke: invoke, superclassCall: await superclassCall(), defaultCall: await defaultCall())
    }

    public func setter<T, IMPL>(
        _ property: String,
        value: T,
        invoke: (IMPL) -> Void,
        superclassCall: @autoclosure () -> Void,
        defaultCall: @autoclosure () -> Void
    ) {
        call(setterName(property), parameters: value, escapingParameters: value, invoke: invoke, superclassCall: superclassCall(), defaultCall: defaultCall())
    }
}

extension MockManager {
    public func getterThrows<T, IMPL>(
        _ property: String,
        invoke: (IMPL) throws -> T,
        superclassCall: @autoclosure () throws -> T,
        defaultCall: @autoclosure () throws -> T
    ) throws -> T {
        try callThrows(getterName(property), parameters: Void(), escapingParameters: Void(), errorType: (any Error).self, invoke: invoke, superclassCall: try superclassCall(), defaultCall: try defaultCall())
    }

    public nonisolated(nonsending) func getterThrows<T, IMPL>(
        _ property: String,
        invoke: nonisolated(nonsending) (IMPL) async throws -> T,
        superclassCall: @autoclosure () async throws -> T,
        defaultCall: @autoclosure () async throws -> T
    ) async throws -> T {
        try await callThrows(getterName(property), parameters: Void(), escapingParameters: Void(), errorType: (any Error).self, invoke: invoke, superclassCall: try await superclassCall(), defaultCall: try await defaultCall())
    }
}

extension MockManager {
    public func call<IN, OUT, IMPL>(
        _ method: String,
        parameters: IN,
        escapingParameters: IN,
        invoke: (IMPL) -> OUT,
        superclassCall: @autoclosure () -> OUT,
        defaultCall: @autoclosure () -> OUT
    ) -> OUT {
        callInternal(method, parameters: parameters, escapingParameters: escapingParameters, invoke: invoke, superclassCall: superclassCall, defaultCall: defaultCall)
    }

    public nonisolated(nonsending) func call<IN, OUT, IMPL>(
        _ method: String,
        parameters: IN,
        escapingParameters: IN,
        invoke: nonisolated(nonsending) (IMPL) async -> OUT,
        superclassCall: @autoclosure () async -> OUT,
        defaultCall: @autoclosure () async -> OUT
    ) async -> OUT {
        await callInternal(method, parameters: parameters, escapingParameters: escapingParameters, invoke: invoke, superclassCall: superclassCall, defaultCall: defaultCall)
    }
}

extension MockManager {
    public func callThrows<IN, OUT, ERROR, IMPL>(
        _ method: String,
        parameters: IN,
        escapingParameters: IN,
        errorType: ERROR.Type,
        invoke: (IMPL) throws(ERROR) -> OUT,
        superclassCall: @autoclosure () throws(ERROR) -> OUT,
        defaultCall: @autoclosure () throws(ERROR) -> OUT
    ) throws(ERROR) -> OUT {
        try callInternal(method, parameters: parameters, escapingParameters: escapingParameters, invoke: invoke, superclassCall: superclassCall, defaultCall: defaultCall)
    }

    public nonisolated(nonsending) func callThrows<IN, OUT, ERROR, IMPL>(
        _ method: String,
        parameters: IN,
        escapingParameters: IN,
        errorType: ERROR.Type,
        invoke: nonisolated(nonsending) (IMPL) async throws(ERROR) -> OUT,
        superclassCall: @autoclosure () async throws(ERROR) -> OUT,
        defaultCall: @autoclosure () async throws(ERROR) -> OUT
    ) async throws(ERROR) -> OUT {
        try await callInternal(method, parameters: parameters, escapingParameters: escapingParameters, invoke: invoke, superclassCall: superclassCall, defaultCall: defaultCall)
    }
}

extension MockManager {
    public func callRethrows<IN, OUT, IMPL>(
        _ method: String,
        parameters: IN,
        escapingParameters: IN,
        invoke: (IMPL) throws -> OUT,
        superclassCall: @autoclosure () throws -> OUT,
        defaultCall: @autoclosure () throws -> OUT
    ) rethrows -> OUT {
        try callInternal(method, parameters: parameters, escapingParameters: escapingParameters, invoke: invoke, superclassCall: superclassCall, defaultCall: defaultCall)
    }

    public nonisolated(nonsending) func callRethrows<IN, OUT, IMPL>(
        _ method: String,
        parameters: IN,
        escapingParameters: IN,
        invoke: nonisolated(nonsending) (IMPL) async throws -> OUT,
        superclassCall: @autoclosure () async throws -> OUT,
        defaultCall: @autoclosure () async throws -> OUT
    ) async rethrows -> OUT {
        try await callInternal(method, parameters: parameters, escapingParameters: escapingParameters, invoke: invoke, superclassCall: superclassCall, defaultCall: defaultCall)
    }
}
