import Foundation

public final class MockManager: Sendable {
    private struct RecordedCall {
        let id: Int
        /// The call's place among the calls to every mock, for `inOrder`.
        let sequence: Int
        let call: any StubCall
    }

    private struct State {
        /// Newest first, so a later stub overrides an earlier one with the same matchers.
        var stubs: [any Stub] = []
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
    /// A mock type's manager for its static members, which have no default implementation to forward to.
    private let isStatic: Bool

    public init(hasParent: Bool) {
        self.hasParent = hasParent
        self.isStatic = false
    }

    init(hasParent: Bool, isStatic: Bool) {
        self.hasParent = hasParent
        self.isStatic = isStatic
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
            state.calls.append(RecordedCall(id: id, sequence: CallSequence.next(), call: call))
            state.unverifiedCallIDs.insert(id)
            return (state.stubs, state.isSuperclassSpyEnabled, state.isDefaultImplementationEnabled)
        }

        // Newest stub first. A stub has no action yet while another thread is still between `when` and
        // `then…`, so it's skipped rather than treated as broken; an older stub can still answer.
        var sawUnfinishedStub = false
        // For each stub that didn't match, newest first, the first argument it rejected.
        var mismatches: [Int] = []
        let candidates = stubs.lazy
            .filter { $0.method == method }
            .compactMap { $0 as? ConcreteStub<IN, OUT, ERROR, IMPL> }
        for stub in candidates {
            if let mismatch = stub.firstMismatch(in: parameters) {
                mismatches.append(mismatch)
                continue
            }
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
            fail("No stub for method `\(method)` using parameters \(parameters).\n" + describeStubs(of: method, mismatches: mismatches))
            return .unstubbed
        }
    }

    /// Why no stub of `method` answered a call: the argument each one rejected, or that there are none.
    private func describeStubs(of method: String, mismatches: [Int]) -> String {
        let member = MemberSignature(method)
        guard !mismatches.isEmpty else {
            return "The mock has no stub for \(member.name)."
        }
        return "Stubs of \(member.name), newest first:\n" + numberedList(mismatches.map { "\(member.argument(at: $0)) doesn't match" })
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
    // The manager hands `invoke` the call's arguments, so the closure captures none of them. Capturing a
    // non-Sendable argument in an actor mock's closure is a "sending ... risks causing data races" error on
    // Swift 6.2.

    private func callInternal<IN, OUT, ERROR, IMPL>(
        _ method: String,
        parameters: IN,
        escapingParameters: IN,
        invoke: (IMPL, IN) throws(ERROR) -> OUT,
        superclassCall: () throws(ERROR) -> OUT,
        defaultCall: () throws(ERROR) -> OUT
    ) throws(ERROR) -> OUT {
        switch resolve(method, parameters: parameters, escapingParameters: escapingParameters, as: (OUT, ERROR, IMPL).self) {
        case .stubbed(.callImplementation(let implementation)):
            return try invoke(implementation, parameters)
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
        invoke: nonisolated(nonsending) (IMPL, IN) async throws(ERROR) -> OUT,
        superclassCall: () async throws(ERROR) -> OUT,
        defaultCall: () async throws(ERROR) -> OUT
    ) async throws(ERROR) -> OUT {
        switch resolve(method, parameters: parameters, escapingParameters: escapingParameters, as: (OUT, ERROR, IMPL).self) {
        case .stubbed(.callImplementation(let implementation)):
            return try await invoke(implementation, parameters)
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
        // Each call to this member with the first argument its matcher rejected, or `nil` if the call matches. Like
        // stub matching, it stops at that argument.
        let callsToMember = recordedCalls.compactMap { recorded -> (recorded: RecordedCall, mismatch: Int?)? in
            guard recorded.call.method == method, let call = recorded.call as? ConcreteStubCall<IN> else { return nil }
            return (recorded, parameterMatchers.firstIndex { !$0.matches(call.parameters) })
        }
        let matching = callsToMember.filter { $0.mismatch == nil }.map(\.recorded)
        if let order = InOrder.current {
            verifyInOrder(order, matching: matching, callMatcher: callMatcher, sourceLocation: sourceLocation)
            return __DoNotUse()
        }
        state.withLock { state in
            state.unverifiedCallIDs.subtract(matching.map(\.id))
        }
        
        let calls = matching.map(\.call)
        if callMatcher.matches(calls) == false {
            let message = "Wanted \(callMatcher.name) but \(calls.count == 0 ? "not invoked" : "invoked \(calls.count) times")."
            reportFailure(message + "\n" + describeCalls(of: method, callsToMember: callsToMember, among: recordedCalls), at: sourceLocation)
        }
        return __DoNotUse()
    }

    /// What a failed `verify` of `method` saw: its calls and the argument each one that didn't match got wrong, or
    /// else every call the mock received.
    private func describeCalls(of method: String, callsToMember: [(recorded: RecordedCall, mismatch: Int?)], among recordedCalls: [RecordedCall]) -> String {
        let member = MemberSignature(method)
        guard !callsToMember.isEmpty else {
            guard !recordedCalls.isEmpty else {
                return "The mock received no calls."
            }
            return "\(member.name) wasn't called. The mock received:\n" + numberedList(recordedCalls.map(\.call.readableDescription))
        }
        return "Calls to \(member.name):\n" + numberedList(callsToMember.map { recorded, mismatch in
            let call = recorded.call.readableDescription
            guard let mismatch else {
                return call + " matches"
            }
            return call + ": \(member.argument(at: mismatch)) doesn't match"
        })
    }

    /// A `verify` inside `inOrder`: it only looks at the calls after the ones the previous `verify` matched.
    private func verifyInOrder(_ order: InOrder, matching: [RecordedCall], callMatcher: CallMatcher, sourceLocation: SourceLocation) {
        let cursor = order.cursor
        let candidates = matching.filter { $0.sequence > cursor }
        guard let accepted = callMatcher.acceptedPrefix(of: candidates, callOf: \.call) else {
            order.involve(self)
            let message = "Wanted \(callMatcher.name) in order but invoked \(candidates.count) times after the previous verification (\(matching.count) times in all)."
            reportFailure(message + "\n" + order.describeCalls(), at: sourceLocation)
            return
        }
        state.withLock { state in
            state.unverifiedCallIDs.subtract(accepted.map(\.id))
        }
        order.advance(past: accepted.map { SequencedCall(sequence: $0.sequence, call: $0.call) }, of: self)
    }

    /// Every recorded call with its place among the calls to every mock.
    func sequencedCalls() -> [SequencedCall] {
        state.withLock { $0.calls.map { SequencedCall(sequence: $0.sequence, call: $0.call) } }
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

    public func enableDefaultStubImplementation(file: StaticString = #file, fileID: String = #fileID, filePath: String = #filePath, line: Int = #line, column: Int = #column) {
        guard !isStatic else {
            fail("Static members have no default implementation. Stub them instead.", file: file, fileID: fileID, filePath: filePath, line: line, column: column)
            return
        }
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
    
    /// An actor mock's `enableDefaultImplementation`. An actor mock never forwards to a default implementation:
    /// that would be another actor, and handing it a non-Sendable argument is a data race.
    public func refuseActorDefaultImplementation(file: StaticString = #file, fileID: String = #fileID, filePath: String = #filePath, line: Int = #line, column: Int = #column) {
        fail("Actor mocks have no default implementation. Stub their members instead.", file: file, fileID: fileID, filePath: filePath, line: line, column: column)
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
            let unverifiedCalls = unverified.map(\.readableDescription)
                .enumerated().map { "\($0 + 1). " + $1 }.joined(separator: "\n")
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

    /// Stands in for forwarding a static member to a default implementation, which only instance members have.
    /// A static manager refuses to enable the default implementation, so this is never called.
    public static func crashOnStaticDefaultImplementationCall<OUT>(_ member: String) -> OUT {
        fatalError("Cuckoo internal error: static member \(member) reached a default implementation, which static members don't have. Please report an issue to the Cuckoo repository.")
    }

    /// Stands in for forwarding a member of an actor mock to a default implementation, which actor mocks don't have.
    /// An actor mock refuses to enable the default implementation, so this is never called.
    public static func crashOnActorDefaultImplementationCall<OUT>(_ member: String) -> OUT {
        fatalError("Cuckoo internal error: actor mock member \(member) reached a default implementation, which actor mocks don't have. Please report an issue to the Cuckoo repository.")
    }

    /// Stands in for forwarding a member that takes or returns `Self` to a default implementation, whose `Self`
    /// is another type than the mock.
    public static func crashOnSelfDefaultImplementationCall<OUT>(_ member: String) -> OUT {
        fatalError("Cuckoo can't call the default implementation of \(member), because it takes or returns Self, which is another type there than the mock. Stub it instead.")
    }

    /// Stands in for forwarding a member with a `~Copyable` argument to the superclass or a default implementation.
    /// The mock forwards through a closure, which can't capture a `~Copyable` argument to pass it on.
    public static func crashOnNoncopyableArgumentForward<OUT>(_ member: String) -> OUT {
        fatalError("Cuckoo can't call the real or default implementation of \(member), because it takes a ~Copyable argument. Stub it instead.")
    }

    /// Narrows an error thrown by a `then` closure to a typed-throws member's error type. The closure's type
    /// throws untyped errors, because a typed-throws function type needs runtime support that iOS 17 and
    /// macOS 14 lack once it's a generic argument.
    public static func typedError<ERROR: Error>(_ error: any Error, as _: ERROR.Type, member: String) -> ERROR {
        guard let typed = error as? ERROR else {
            fatalError("The stub for \(member) threw \(error), which isn't a \(ERROR.self).")
        }
        return typed
    }
}

extension MockManager {
    public func getter<T, IMPL>(
        _ property: String,
        invoke: (IMPL) -> T,
        superclassCall: @autoclosure () -> T,
        defaultCall: @autoclosure () -> T
    ) -> T {
        call(getterName(property), parameters: Void(), escapingParameters: Void(), invoke: { implementation, _ in invoke(implementation) }, superclassCall: superclassCall(), defaultCall: defaultCall())
    }

    public nonisolated(nonsending) func getter<T, IMPL>(
        _ property: String,
        invoke: nonisolated(nonsending) (IMPL) async -> T,
        superclassCall: @autoclosure () async -> T,
        defaultCall: @autoclosure () async -> T
    ) async -> T {
        await call(getterName(property), parameters: Void(), escapingParameters: Void(), invoke: { implementation, _ in await invoke(implementation) }, superclassCall: await superclassCall(), defaultCall: await defaultCall())
    }

    public func setter<T, IMPL>(
        _ property: String,
        value: T,
        invoke: (IMPL, T) -> Void,
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
        try callThrows(getterName(property), parameters: Void(), escapingParameters: Void(), errorType: (any Error).self, invoke: { implementation, _ in try invoke(implementation) }, superclassCall: try superclassCall(), defaultCall: try defaultCall())
    }

    public nonisolated(nonsending) func getterThrows<T, IMPL>(
        _ property: String,
        invoke: nonisolated(nonsending) (IMPL) async throws -> T,
        superclassCall: @autoclosure () async throws -> T,
        defaultCall: @autoclosure () async throws -> T
    ) async throws -> T {
        try await callThrows(getterName(property), parameters: Void(), escapingParameters: Void(), errorType: (any Error).self, invoke: { implementation, _ in try await invoke(implementation) }, superclassCall: try await superclassCall(), defaultCall: try await defaultCall())
    }
}

extension MockManager {
    public func call<IN, OUT, IMPL>(
        _ method: String,
        parameters: IN,
        escapingParameters: IN,
        invoke: (IMPL, IN) -> OUT,
        superclassCall: @autoclosure () -> OUT,
        defaultCall: @autoclosure () -> OUT
    ) -> OUT {
        callInternal(method, parameters: parameters, escapingParameters: escapingParameters, invoke: invoke, superclassCall: superclassCall, defaultCall: defaultCall)
    }

    public nonisolated(nonsending) func call<IN, OUT, IMPL>(
        _ method: String,
        parameters: IN,
        escapingParameters: IN,
        invoke: nonisolated(nonsending) (IMPL, IN) async -> OUT,
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
        invoke: (IMPL, IN) throws(ERROR) -> OUT,
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
        invoke: nonisolated(nonsending) (IMPL, IN) async throws(ERROR) -> OUT,
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
        invoke: (IMPL, IN) throws -> OUT,
        superclassCall: @autoclosure () throws -> OUT,
        defaultCall: @autoclosure () throws -> OUT
    ) rethrows -> OUT {
        try callInternal(method, parameters: parameters, escapingParameters: escapingParameters, invoke: invoke, superclassCall: superclassCall, defaultCall: defaultCall)
    }

    public nonisolated(nonsending) func callRethrows<IN, OUT, IMPL>(
        _ method: String,
        parameters: IN,
        escapingParameters: IN,
        invoke: nonisolated(nonsending) (IMPL, IN) async throws -> OUT,
        superclassCall: @autoclosure () async throws -> OUT,
        defaultCall: @autoclosure () async throws -> OUT
    ) async rethrows -> OUT {
        try await callInternal(method, parameters: parameters, escapingParameters: escapingParameters, invoke: invoke, superclassCall: superclassCall, defaultCall: defaultCall)
    }
}
