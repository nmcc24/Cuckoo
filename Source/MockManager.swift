import Foundation

/// Records a mock's calls and holds its stubs. Every generated mock owns one, as `cuckooManager`.
///
/// Tests don't call it directly: ``stub(_:block:)-(M,_)``, ``verify(_:_:fileID:filePath:line:column:)->M.CuckooVerification``
/// and the reset functions go through it. Its methods are public for the generated mocks.
public final class MockManager: Sendable {
    private struct RecordedCall {
        let id: Int
        /// The call's place among the calls to every mock, for `inOrder`.
        let sequence: Int
        let call: any StubCall
        /// The call's return type, which tells a generic member's calls apart when only it differs.
        let returnType: Any.Type
    }

    private struct State {
        /// Newest first, so a later stub overrides an earlier one with the same matchers.
        var stubs: [any Stub] = []
        var calls: [RecordedCall] = []
        var unverifiedCallIDs: Set<Int> = []
        var nextCallID = 0
        var fallback = Fallback.none
        /// Whether the mock has been stubbed or called, after which its fallback can't change. Neither `reset` nor
        /// `clearInvocations` clears it: a test's mock is set up once, when it's created.
        var isInUse = false
    }

    /// What answers a call that no stub matches. A mock has one at most.
    private enum Fallback {
        case none
        /// `enableSuperclassSpy()`: the superclass's real implementation.
        case superclass
        /// `enableDefaultImplementation(_:)`: the default implementation.
        case defaultImplementation
    }

    /// What a call resolves to once it has been recorded.
    private enum Resolution<OUT, ERROR: Error, IMPL> {
        case stubbed(StubAction<OUT, ERROR, IMPL>)
        case superclass
        case defaultImplementation
        /// No stub answers the call, for the reason `failure` gives. It's reported once the call knows whether it
        /// returns a default value or stops the process, so a crash reports it only once.
        case unstubbed(failure: String)
    }

    // All mutable state sits behind one lock. User code (matchers, stub implementations, the superclass and
    // default implementations) always runs outside it, so it may call back into the mock.
    private let state = Locked(State())
    private let hasParent: Bool
    /// A mock type's manager for its static members, which have no default implementation to forward to.
    private let isStatic: Bool
    /// The Swift Testing test the mock was created in, so a failure from a task outside the test, which doesn't
    /// know the test, still goes to Swift Testing rather than XCTest.
    let creatingTest: CreatingTest?
    /// The default values of the scope the mock was created in, such as a test's `.cuckoo(defaultValues:)` trait,
    /// for an unstubbed call from a task outside that scope, which doesn't see them.
    private let creatingDefaultValues: DefaultValues

    /// Creates the manager of a mock. `hasParent` says whether the mock can call a real implementation.
    public convenience init(hasParent: Bool) {
        self.init(hasParent: hasParent, isStatic: false)
    }

    init(hasParent: Bool, isStatic: Bool) {
        self.hasParent = hasParent
        self.isStatic = isStatic
        self.creatingTest = CreatingTest.current
        self.creatingDefaultValues = CuckooConfiguration.current.defaultValues
    }

    /// Records the call and decides how to answer it. Crashes if the call can't be answered.
    private func resolve<IN, OUT, ERROR, IMPL>(
        _ method: String,
        parameters: IN,
        escapingParameters: IN,
        as _: (OUT, ERROR, IMPL).Type
    ) -> Resolution<OUT, ERROR, IMPL> {
        let call = ConcreteStubCall(method: method, parameters: escapingParameters)
        let (stubs, fallback) = state.withLock { state in
            let id = state.nextCallID
            state.nextCallID += 1
            state.calls.append(RecordedCall(id: id, sequence: CallSequence.next(), call: call, returnType: OUT.self))
            state.unverifiedCallIDs.insert(id)
            state.isInUse = true
            return (state.stubs, state.fallback)
        }

        // Newest stub first. A stub has no action yet while another thread is still between `when` and
        // `then…`, so it's skipped rather than treated as broken; an older stub can still answer.
        var sawUnfinishedStub = false
        // For each stub that didn't match, newest first, the first argument it rejected.
        var mismatches: [Int] = []
        let sameMember = stubs.filter { $0.method == method }
        let candidates = sameMember.lazy.compactMap { $0 as? ConcreteStub<IN, OUT, ERROR, IMPL> }
        for stub in candidates {
            // A captor in the stub's matchers captures only if this stub answers the call.
            let (mismatch, captures) = PendingCaptures.collecting { stub.firstMismatch(in: parameters) }
            if let mismatch {
                mismatches.append(mismatch)
                continue
            }
            guard let action = stub.nextAction() else {
                sawUnfinishedStub = true
                continue
            }
            captures.commit()
            if case .callRealImplementation = action {
                guard hasParent else {
                    failAndCrash("\(call.memberAndArguments) has no real implementation to call: the mock's type has no superclass.")
                }
                return .superclass
            }
            return .stubbed(action)
        }

        if fallback == .superclass {
            return .superclass
        } else if fallback == .defaultImplementation {
            return .defaultImplementation
        } else if sawUnfinishedStub {
            return .unstubbed(failure: "The stub that matches \(call.memberAndArguments) has no answer. Give it one, such as thenReturn(_:), after when(_:).")
        } else {
            // A generic member's stubs made with other type arguments can't answer this call.
            let callTypes = describeTypes(arguments: IN.self, result: OUT.self)
            let otherTypes = sameMember.compactMap { ($0 as? any TypedStub)?.types }.filter { $0 != callTypes }
            return .unstubbed(
                failure: "No stub for \(call.memberAndArguments).\n"
                    + describeStubs(of: method, mismatches: mismatches, otherTypes: otherTypes, callTypes: callTypes)
            )
        }
    }

    /// Why no stub of `method` answered a call: the argument each one rejected, or that there are none.
    ///
    /// `otherTypes` are the argument and return types of the member's stubs made for other type arguments, which a
    /// generic member's call with `callTypes` can't use.
    private func describeStubs(of method: String, mismatches: [Int], otherTypes: [String], callTypes: String) -> String {
        let member = MemberSignature(method)
        var lines: [String] = []
        if mismatches.isEmpty && otherTypes.isEmpty {
            lines.append("The mock has no stub for \(member.name).")
        } else if !mismatches.isEmpty {
            lines.append("Stubs of \(member.name), newest first:\n" + numberedList(mismatches.map { "\(member.argument(at: $0)) doesn't match" }))
        }
        if !otherTypes.isEmpty {
            lines.append(
                "Stubs of \(member.name) made for other types, which can't answer a call with \(callTypes):\n"
                    + numberedList(otherTypes)
            )
        }
        return lines.joined(separator: "\n")
    }

    /// The current configuration, with the default values of the scope the mock was created in for the types the
    /// current scope doesn't register.
    private var configurationWithCreatingDefaults: CuckooConfiguration {
        var configuration = CuckooConfiguration.current
        configuration.defaultValues = configuration.defaultValues.withFallback(creatingDefaultValues)
        return configuration
    }

    /// Reports `failure` and returns the default value of an unstubbed call, or, if its type has none, reports it
    /// and crashes. `generated` is the generated mock's own default, for a type with no registered one: the lookup of a
    /// tuple's elements, which a generic `OUT` can't name, a new `…Stub` of a mocked protocol, or a value of one of
    /// the sources' own types.
    private func unstubbedValue<OUT>(failure: String, generated: () -> Any?) -> OUT {
        let value = CuckooConfiguration.$current.withValue(configurationWithCreatingDefaults) {
            DefaultValueRegistry.unstubbedValue(for: OUT.self) ?? generated() as? OUT
        }
        guard let value else {
            failAndCrash("\(failure)\nIts return type, \(OUT.self), has no default value. Stub it, or register one with `DefaultValueRegistry` or the `.cuckoo(defaultValues:)` trait.")
        }
        fail(failure)
        return value
    }

    /// Stands in for forwarding `member` to a default implementation that a protocol mock's type eraser can't
    /// forward it to, for `reason`, such as an `inout` parameter: it records a failure saying to stub the member, for
    /// the test that created the mock, and returns the default value an unstubbed call would, even for a member that
    /// throws, so the test goes on. Generated mocks pass `unstubbedDefault` for a member returning a tuple, or a type
    /// they build a default of themselves: a mocked protocol's stub, or a value of one of the sources' own types.
    public func unforwardableDefaultImplementationCall<OUT>(_ member: String, reason: String, unstubbedDefault: @autoclosure () -> Any? = nil) -> OUT {
        unstubbedValue(failure: "Cuckoo can't forward \(member) to the default implementation: \(reason). Stub it instead.", generated: unstubbedDefault)
    }

    /// The error an unstubbed throwing call throws, if its error type can hold `CuckooError`.
    private func unstubbedError<ERROR: Error>(_ method: String, as _: ERROR.Type) -> ERROR? {
        CuckooError.unstubbedCall(method: method) as? ERROR
    }

    // The `call` variants below differ only in effects. `invoke` runs a `then` closure: the generated mock
    // passes it, so the closure runs in the mock's isolation and the manager never calls user code itself.
    // The manager hands `invoke` the call's arguments, so the closure captures none of them. Capturing a
    // non-Sendable argument in an actor mock's closure was a "sending ... risks causing data races" error on
    // Swift 6.2, and passing them in keeps the closures free of captured arguments.
    // `unstubbedDefault` is the default the mock builds for a return type the registry has none for: a tuple's, from
    // its elements' defaults, a new `…Stub` of a protocol the module mocks, or a value of one of the sources' own
    // types. It runs in the mock's isolation too, and only for a call that nothing else answers.

    private func callInternal<IN, OUT, ERROR, IMPL>(
        _ method: String,
        parameters: IN,
        escapingParameters: IN,
        invoke: (IMPL, IN) throws(ERROR) -> OUT,
        superclassCall: () throws(ERROR) -> OUT,
        defaultCall: () throws(ERROR) -> OUT,
        unstubbedDefault: () -> Any?,
        unstubbedThrows: Bool = true
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
            // The default implementation sees the mock's default values too: a generated `…Stub` returns them. With
            // none, it runs in the current scope, so a crash inside it raises from no scope of Cuckoo's.
            guard !creatingDefaultValues.isEmpty else {
                return try defaultCall()
            }
            let result: Result<OUT, ERROR> = CuckooConfiguration.$current.withValue(configurationWithCreatingDefaults) {
                do throws(ERROR) {
                    return .success(try defaultCall())
                } catch {
                    return .failure(error)
                }
            }
            return try result.get()
        case .unstubbed(let failure):
            if unstubbedThrows, let error = unstubbedError(method, as: ERROR.self) {
                fail(failure)
                throw error
            }
            return unstubbedValue(failure: failure, generated: unstubbedDefault)
        }
    }

    private nonisolated(nonsending) func callInternal<IN, OUT, ERROR, IMPL>(
        _ method: String,
        parameters: IN,
        escapingParameters: IN,
        invoke: nonisolated(nonsending) (IMPL, IN) async throws(ERROR) -> OUT,
        superclassCall: () async throws(ERROR) -> OUT,
        defaultCall: () async throws(ERROR) -> OUT,
        unstubbedDefault: () -> Any?,
        unstubbedThrows: Bool = true
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
            guard !creatingDefaultValues.isEmpty else {
                return try await defaultCall()
            }
            let result: Result<OUT, ERROR> = await CuckooConfiguration.$current.withValue(configurationWithCreatingDefaults) {
                do throws(ERROR) {
                    return .success(try await defaultCall())
                } catch {
                    return .failure(error)
                }
            }
            return try result.get()
        case .unstubbed(let failure):
            if unstubbedThrows, let error = unstubbedError(method, as: ERROR.self) {
                fail(failure)
                throw error
            }
            return unstubbedValue(failure: failure, generated: unstubbedDefault)
        }
    }

    /// Adds a stub of a class mock's `method` for calls whose arguments match `parameterMatchers`.
    public func createStub<MOCK: ClassMock, IN, OUT, ERROR, IMPL>(for _: MOCK.Type, method: String, parameterMatchers: [ParameterMatcher<IN>]) -> ClassConcreteStub<IN, OUT, ERROR, IMPL> {
        let stub = ClassConcreteStub<IN, OUT, ERROR, IMPL>(method: method, parameterMatchers: parameterMatchers)
        state.withLock { state in
            state.stubs.insert(stub, at: 0)
            state.isInUse = true
        }
        return stub
    }

    /// Adds a stub of a protocol mock's `method` for calls whose arguments match `parameterMatchers`.
    public func createStub<MOCK: ProtocolMock, IN, OUT, ERROR, IMPL>(for _: MOCK.Type, method: String, parameterMatchers: [ParameterMatcher<IN>]) -> ConcreteStub<IN, OUT, ERROR, IMPL> {
        let stub = ConcreteStub<IN, OUT, ERROR, IMPL>(method: method, parameterMatchers: parameterMatchers)
        state.withLock { state in
            state.stubs.insert(stub, at: 0)
            state.isInUse = true
        }
        return stub
    }

    /// Adds a stub of a `Sendable` class mock's `method` for calls whose arguments match `parameterMatchers`.
    @_disfavoredOverload
    public func createStub<MOCK: ClassMock, IN, OUT, ERROR, IMPL>(for mock: MOCK.Type, method: String, parameterMatchers: [SendableMatcher<IN>]) -> ClassConcreteStub<IN, OUT, ERROR, IMPL> {
        createStub(for: mock, method: method, parameterMatchers: parameterMatchers.map(\.matcher))
    }

    /// Adds a stub of a `Sendable` protocol mock's `method` for calls whose arguments match `parameterMatchers`.
    @_disfavoredOverload
    public func createStub<MOCK: ProtocolMock, IN, OUT, ERROR, IMPL>(for mock: MOCK.Type, method: String, parameterMatchers: [SendableMatcher<IN>]) -> ConcreteStub<IN, OUT, ERROR, IMPL> {
        createStub(for: mock, method: method, parameterMatchers: parameterMatchers.map(\.matcher))
    }

    /// Checks the recorded calls of `method` whose arguments match `parameterMatchers` against `callMatcher`, and
    /// reports a failure at `sourceLocation` when they don't match.
    ///
    /// Only the calls that returned `OUT` count, as only the stubs returning it answer them: a generic member called
    /// with another return type is another call. A verification proxy names the same `OUT` as the stubbing proxy,
    /// or `Any`, which counts every call, for a member whose return type names a generic parameter the proxy omits.
    public func verify<IN, OUT>(_ method: String, callMatcher: CallMatcher, parameterMatchers: [ParameterMatcher<IN>], sourceLocation: CuckooSourceLocation) -> VerifiedCall<IN, OUT> {
        let recordedCalls = state.withLock { $0.calls }
        // Each call to this member with the first argument its matcher rejected, or `nil` if the call matches. Like
        // stub matching, it stops at that argument. A captor's captures wait until the `verify` passes.
        let callsToMember = recordedCalls.compactMap { recorded -> (recorded: RecordedCall, mismatch: Int?, captures: PendingCaptures)? in
            guard recorded.call.method == method, OUT.self == Any.self || recorded.returnType == OUT.self,
                  let call = recorded.call as? ConcreteStubCall<IN> else { return nil }
            let (mismatch, captures) = PendingCaptures.collecting { parameterMatchers.firstIndex { !$0.matches(call.parameters) } }
            return (recorded, mismatch, captures)
        }
        let matchingCalls = callsToMember.filter { $0.mismatch == nil }
        let matching = matchingCalls.map(\.recorded)
        if let order = InOrder.current {
            // Checked when the `inOrder` block ends; the calls it takes are verified and captured then.
            order.add(InOrderStep(
                manager: self,
                matching: matchingCalls.map { SequencedCall(sequence: $0.recorded.sequence, call: $0.recorded.call) },
                callMatcher: callMatcher,
                sourceLocation: sourceLocation,
                take: { sequences in
                    let taken = matchingCalls.filter { sequences.contains($0.recorded.sequence) }
                    self.state.withLock { state in
                        state.unverifiedCallIDs.subtract(taken.map(\.recorded.id))
                    }
                    taken.forEach { $0.captures.commit() }
                }
            ))
            return VerifiedCall()
        }
        let calls = matching.map(\.call)
        guard callMatcher.matches(calls) else {
            // The calls stay unverified, so `verifyNoMoreInteractions` still reports them.
            let message = "Wanted \(callMatcher.name) but \(calls.isEmpty ? "not invoked" : "invoked \(timesDescription(calls.count))")."
            // A generic member's calls with other argument or return types, which this `verify` doesn't count.
            let otherTypes = callsToMember.isEmpty
                ? recordedCalls.filter { $0.call.method == method }.map { recorded in
                    describeTypes(arguments: (recorded.call as? any TypedCall)?.argumentsType ?? Any.self, result: recorded.returnType)
                }
                : []
            let described = describeCalls(of: method, callsToMember: callsToMember.map { ($0.recorded, $0.mismatch) }, otherTypes: otherTypes, among: recordedCalls)
            reportFailure(message + "\n" + described, at: sourceLocation, creatingTest: creatingTest)
            return VerifiedCall()
        }
        state.withLock { state in
            state.unverifiedCallIDs.subtract(matching.map(\.id))
        }
        matchingCalls.forEach { $0.captures.commit() }
        return VerifiedCall()
    }

    /// What a failed `verify` of `method` saw: its calls and the argument each one that didn't match got wrong, or
    /// else the argument and return types it was called with instead, or else every call the mock received.
    private func describeCalls(of method: String, callsToMember: [(recorded: RecordedCall, mismatch: Int?)], otherTypes: [String], among recordedCalls: [RecordedCall]) -> String {
        let member = MemberSignature(method)
        guard !callsToMember.isEmpty else {
            guard !recordedCalls.isEmpty else {
                return "The mock received no calls."
            }
            if !otherTypes.isEmpty {
                var unique: [String] = []
                for type in otherTypes where !unique.contains(type) {
                    unique.append(type)
                }
                return "\(member.name) was called only with other types, which this `verify` doesn't count:\n"
                    + numberedList(unique)
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

    /// Every recorded call with its place among the calls to every mock.
    func sequencedCalls() -> [SequencedCall] {
        state.withLock { $0.calls.map { SequencedCall(sequence: $0.sequence, call: $0.call) } }
    }

    /// Makes unstubbed calls run the superclass's real implementation. Allowed only before the mock's first stub or
    /// call.
    public func enableSuperclassSpy() {
        guard hasParent else {
            fail("A protocol mock has no superclass to spy on. Use enableDefaultImplementation(_:) to forward its calls to a real implementation.")
            return
        }
        let error: String? = state.withLock { state in
            switch state.fallback {
            case .superclass:
                return nil
            case .defaultImplementation:
                return "Enabling superclass spy is not allowed with the default implementation enabled."
            case .none:
                guard !state.isInUse else {
                    return "Enabling superclass spy is not allowed after the mock's first stub or call. Enable it right after creating the mock, or first in createMock's closure."
                }
                state.fallback = .superclass
                return nil
            }
        }
        if let error {
            failAndCrash(error)
        }
    }

    /// Makes unstubbed calls forward to the default implementation. Allowed only before the mock's first stub or
    /// call, as is replacing it, which a generated mock does before calling this.
    public func enableDefaultImplementation(fileID: String = #fileID, filePath: StaticString = #filePath, line: Int = #line, column: Int = #column) {
        guard !isStatic else {
            fail("Static members have no default implementation. Stub them instead.", at: (fileID, filePath, line, column))
            return
        }
        let error: String? = state.withLock { state in
            switch state.fallback {
            case .superclass:
                return "Enabling the default implementation is not allowed with superclass spy enabled."
            case .none, .defaultImplementation:
                guard !state.isInUse else {
                    return "Enabling the default implementation is not allowed after the mock's first stub or call. Enable it right after creating the mock."
                }
                state.fallback = .defaultImplementation
                return nil
            }
        }
        if let error {
            failAndCrash(error)
        }
    }
    
    /// An actor mock's `enableDefaultImplementation`. An actor mock never forwards to a default implementation:
    /// that would be another actor, and handing it a non-Sendable argument is a data race.
    public func refuseActorDefaultImplementation(fileID: String = #fileID, filePath: StaticString = #filePath, line: Int = #line, column: Int = #column) {
        fail("Actor mocks have no default implementation. Stub their members instead.", at: (fileID, filePath, line, column))
    }

    // The removed stubs and calls are released after the lock is, since releasing them can run user code (a
    // recorded argument's or a stub closure's captured value's `deinit`), which may call the mock. Each function keeps
    // them alive past the lock with `withExtendedLifetime`: a discarded result (`_ = withLock { … }`) lets the
    // optimizer release them inside it.

    func reset() {
        let removed = state.withLock { state in
            defer {
                state.stubs = []
                state.calls = []
                state.unverifiedCallIDs.removeAll()
            }
            return (state.stubs, state.calls)
        }
        withExtendedLifetime(removed) {}
    }

    func clearStubs() {
        let removed = state.withLock { state in
            defer { state.stubs = [] }
            return state.stubs
        }
        withExtendedLifetime(removed) {}
    }

    func clearInvocations() {
        let removed = state.withLock { state in
            defer {
                state.calls = []
                state.unverifiedCallIDs.removeAll()
            }
            return state.calls
        }
        withExtendedLifetime(removed) {}
    }
    
    /// - Parameters:
    ///   - globalActor: The actor the mock records its calls on, if any.
    ///   - caller: The caller's isolation. Off `globalActor`, the calls aren't read: a failure says why.
    func verifyNoMoreInteractions(_ sourceLocation: CuckooSourceLocation, mockType: Any.Type, globalActor: (any Actor)?, caller: (any Actor)?) {
        if let globalActor, !Self.isRunning(on: globalActor, caller: caller) {
            reportFailure(
                "verifyNoMoreInteractions(\(mockType)) must run on \(type(of: globalActor)), where the mock records its calls: "
                    + "mark the test or the calling function with that actor.",
                at: sourceLocation,
                creatingTest: creatingTest
            )
            return
        }
        if let order = InOrder.current {
            // Inside `inOrder`, the block's earlier `verify` calls take their calls when it ends, so this waits too.
            order.addDeferred(at: sourceLocation, creatingTest: creatingTest) {
                self.reportUnverifiedCalls(sourceLocation)
            }
            return
        }
        reportUnverifiedCalls(sourceLocation)
    }

    private func reportUnverifiedCalls(_ sourceLocation: CuckooSourceLocation) {
        let unverified = state.withLock { state in
            state.calls.filter { state.unverifiedCallIDs.contains($0.id) }.map(\.call)
        }
        if unverified.isEmpty == false {
            let unverifiedCalls = unverified.map(\.readableDescription)
                .enumerated().map { "\($0 + 1). " + $1 }.joined(separator: "\n")
            let message = "No more interactions wanted but some found:\n"
            reportFailure(message + unverifiedCalls, at: sourceLocation, creatingTest: creatingTest)
        }
    }

    /// Whether code isolated to `caller` runs on `globalActor`. Nonisolated code on the main thread runs on the main
    /// actor's executor too, as a synchronous XCTest method does.
    private static func isRunning(on globalActor: any Actor, caller: (any Actor)?) -> Bool {
        if let caller, caller === globalActor {
            return true
        }
        return globalActor === MainActor.shared && Thread.isMainThread
    }

    /// Reports a failure at `sourceLocation`, or, for a mock's call, which has no location in the test, at the test.
    private func fail(_ message: String, at sourceLocation: CuckooSourceLocation? = nil) {
        reportFailure(message, at: sourceLocation, creatingTest: creatingTest)
    }

    /// Reports a failure the mock can't go on from, and stops, in every test framework: Swift has no way out of a
    /// call that has to return a value it doesn't have. An Objective-C exception, which XCTest catches, would unwind
    /// past Swift's cleanup, leaving locks held and task-local scopes open for the next tests.
    private func failAndCrash(_ message: String) -> Never {
        reportFailure(message, at: nil, creatingTest: creatingTest)
        fatalError(message)
    }
}

extension MockManager {
    /// Stands in for a protocol mock's superclass call, which can't happen.
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

    /// Stands in for forwarding a member with a `~Copyable` argument to the superclass or a default implementation.
    /// The mock forwards through a closure, which can't capture a `~Copyable` argument to pass it on.
    public static func crashOnNoncopyableArgumentForward<OUT>(_ member: String) -> OUT {
        fatalError("Cuckoo can't call the real or default implementation of \(member), because it takes a ~Copyable argument. Stub it instead.")
    }


    /// A variadic argument is an array inside the mock, and Swift can't pass an array on as separate arguments, so
    /// the mock can't call the real or default implementation of a member that takes one.
    public static func crashOnVariadicArgumentForward<OUT>(_ member: String) -> OUT {
        fatalError("Cuckoo can't call the real or default implementation of \(member), because it takes a variadic argument. Stub it instead.")
    }

    /// The default value of a tuple a mock returns, for a call nothing stubs: the registered one for the tuple type,
    /// else each element's. Generated mocks pass it to the call, since the manager's generic return type can't
    /// name a tuple's elements.
    public static func unstubbedTupleValue<P1, P2, each P>(for type: (P1, P2, repeat each P).Type) -> Any? {
        DefaultValueRegistry.unstubbedValue(for: type).map { $0 as Any }
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
    /// Records a read of `property` and answers it from a stub, the superclass or the default implementation.
    public func getter<T, IMPL>(
        _ property: String,
        invoke: (IMPL) -> T,
        superclassCall: @autoclosure () -> T,
        defaultCall: @autoclosure () -> T,
        unstubbedDefault: @autoclosure () -> Any? = nil
    ) -> T {
        call(getterName(property), parameters: Void(), escapingParameters: Void(), invoke: { implementation, _ in invoke(implementation) }, superclassCall: superclassCall(), defaultCall: defaultCall(), unstubbedDefault: unstubbedDefault())
    }

    /// Records a read of an async `property` and answers it from a stub, the superclass or the default implementation.
    public nonisolated(nonsending) func getter<T, IMPL>(
        _ property: String,
        invoke: nonisolated(nonsending) (IMPL) async -> T,
        superclassCall: @autoclosure () async -> T,
        defaultCall: @autoclosure () async -> T,
        unstubbedDefault: @autoclosure () -> Any? = nil
    ) async -> T {
        await call(getterName(property), parameters: Void(), escapingParameters: Void(), invoke: { implementation, _ in await invoke(implementation) }, superclassCall: await superclassCall(), defaultCall: await defaultCall(), unstubbedDefault: unstubbedDefault())
    }

    /// Records an assignment to `property` and answers it from a stub, the superclass or the default implementation.
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
    /// Records a read of a throwing `property` and answers it from a stub, the superclass or the default
    /// implementation.
    public func getterThrows<T, IMPL>(
        _ property: String,
        invoke: (IMPL) throws -> T,
        superclassCall: @autoclosure () throws -> T,
        defaultCall: @autoclosure () throws -> T,
        unstubbedDefault: @autoclosure () -> Any? = nil
    ) throws -> T {
        try callThrows(getterName(property), parameters: Void(), escapingParameters: Void(), errorType: (any Error).self, invoke: { implementation, _ in try invoke(implementation) }, superclassCall: try superclassCall(), defaultCall: try defaultCall(), unstubbedDefault: unstubbedDefault())
    }

    /// Records a read of an async throwing `property` and answers it from a stub, the superclass or the default
    /// implementation.
    public nonisolated(nonsending) func getterThrows<T, IMPL>(
        _ property: String,
        invoke: nonisolated(nonsending) (IMPL) async throws -> T,
        superclassCall: @autoclosure () async throws -> T,
        defaultCall: @autoclosure () async throws -> T,
        unstubbedDefault: @autoclosure () -> Any? = nil
    ) async throws -> T {
        try await callThrows(getterName(property), parameters: Void(), escapingParameters: Void(), errorType: (any Error).self, invoke: { implementation, _ in try await invoke(implementation) }, superclassCall: try await superclassCall(), defaultCall: try await defaultCall(), unstubbedDefault: unstubbedDefault())
    }
}

extension MockManager {
    /// Records a call of `method` and answers it from a stub, the superclass or the default implementation.
    public func call<IN, OUT, IMPL>(
        _ method: String,
        parameters: IN,
        escapingParameters: IN,
        invoke: (IMPL, IN) -> OUT,
        superclassCall: @autoclosure () -> OUT,
        defaultCall: @autoclosure () -> OUT,
        unstubbedDefault: @autoclosure () -> Any? = nil
    ) -> OUT {
        callInternal(method, parameters: parameters, escapingParameters: escapingParameters, invoke: invoke, superclassCall: superclassCall, defaultCall: defaultCall, unstubbedDefault: unstubbedDefault)
    }

    /// Records a call of an async `method` and answers it from a stub, the superclass or the default implementation.
    public nonisolated(nonsending) func call<IN, OUT, IMPL>(
        _ method: String,
        parameters: IN,
        escapingParameters: IN,
        invoke: nonisolated(nonsending) (IMPL, IN) async -> OUT,
        superclassCall: @autoclosure () async -> OUT,
        defaultCall: @autoclosure () async -> OUT,
        unstubbedDefault: @autoclosure () -> Any? = nil
    ) async -> OUT {
        await callInternal(method, parameters: parameters, escapingParameters: escapingParameters, invoke: invoke, superclassCall: superclassCall, defaultCall: defaultCall, unstubbedDefault: unstubbedDefault)
    }
}

extension MockManager {
    /// Records a call of a throwing `method` and answers it from a stub, the superclass or the default implementation.
    public func callThrows<IN, OUT, ERROR, IMPL>(
        _ method: String,
        parameters: IN,
        escapingParameters: IN,
        errorType: ERROR.Type,
        invoke: (IMPL, IN) throws(ERROR) -> OUT,
        superclassCall: @autoclosure () throws(ERROR) -> OUT,
        defaultCall: @autoclosure () throws(ERROR) -> OUT,
        unstubbedDefault: @autoclosure () -> Any? = nil
    ) throws(ERROR) -> OUT {
        try callInternal(method, parameters: parameters, escapingParameters: escapingParameters, invoke: invoke, superclassCall: superclassCall, defaultCall: defaultCall, unstubbedDefault: unstubbedDefault)
    }

    /// Records a call of an async throwing `method` and answers it from a stub, the superclass or the default
    /// implementation.
    public nonisolated(nonsending) func callThrows<IN, OUT, ERROR, IMPL>(
        _ method: String,
        parameters: IN,
        escapingParameters: IN,
        errorType: ERROR.Type,
        invoke: nonisolated(nonsending) (IMPL, IN) async throws(ERROR) -> OUT,
        superclassCall: @autoclosure () async throws(ERROR) -> OUT,
        defaultCall: @autoclosure () async throws(ERROR) -> OUT,
        unstubbedDefault: @autoclosure () -> Any? = nil
    ) async throws(ERROR) -> OUT {
        try await callInternal(method, parameters: parameters, escapingParameters: escapingParameters, invoke: invoke, superclassCall: superclassCall, defaultCall: defaultCall, unstubbedDefault: unstubbedDefault)
    }
}

extension MockManager {
    /// Records a call of a rethrowing `method` and answers it from a stub, the superclass or the default
    /// implementation.
    ///
    /// An unstubbed call returns a default value instead of throwing ``CuckooError/unstubbedCall(method:)``: the
    /// caller may have passed closures that don't throw, and then has no `try` to catch the error with.
    public func callRethrows<IN, OUT, IMPL>(
        _ method: String,
        parameters: IN,
        escapingParameters: IN,
        invoke: (IMPL, IN) throws -> OUT,
        superclassCall: @autoclosure () throws -> OUT,
        defaultCall: @autoclosure () throws -> OUT,
        unstubbedDefault: @autoclosure () -> Any? = nil
    ) rethrows -> OUT {
        try callInternal(method, parameters: parameters, escapingParameters: escapingParameters, invoke: invoke, superclassCall: superclassCall, defaultCall: defaultCall, unstubbedDefault: unstubbedDefault, unstubbedThrows: false)
    }

    /// Records a call of an async rethrowing `method` and answers it from a stub, the superclass or the default
    /// implementation.
    ///
    /// An unstubbed call returns a default value instead of throwing, as the synchronous `callRethrows` does.
    public nonisolated(nonsending) func callRethrows<IN, OUT, IMPL>(
        _ method: String,
        parameters: IN,
        escapingParameters: IN,
        invoke: nonisolated(nonsending) (IMPL, IN) async throws -> OUT,
        superclassCall: @autoclosure () async throws -> OUT,
        defaultCall: @autoclosure () async throws -> OUT,
        unstubbedDefault: @autoclosure () -> Any? = nil
    ) async rethrows -> OUT {
        try await callInternal(method, parameters: parameters, escapingParameters: escapingParameters, invoke: invoke, superclassCall: superclassCall, defaultCall: defaultCall, unstubbedDefault: unstubbedDefault, unstubbedThrows: false)
    }
}
