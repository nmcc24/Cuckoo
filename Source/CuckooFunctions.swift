/// Stubs members of `mock`.
///
/// The block receives the mock's stubbing proxy: `stub(mock) { stub in when(stub.greet(any())).thenReturn("Hi") }`.
/// Call it as often as needed; a newer stub of the same call takes precedence over older ones.
public func stub<M: Mock>(_ mock: M, block: (M.CuckooStubbing) -> Void) {
    block(mock.cuckooStubbingProxy())
}

/// Names the member being stubbed inside a ``stub(_:block:)-(M,_)`` block, as in
/// `when(stub.count(characters: any())).thenReturn(1)` or `when(stub.count.get)`.
///
/// It returns `function` itself, so that the stub reads as a sentence; the `then` action that follows gives the stub its answer.
public func when<F: BaseStubFunctionTrait>(_ function: F) -> F {
    return function
}

/// Returns a proxy that checks the calls `mock` received, for example `verify(mock, times(2)).greet("Ann")`.
///
/// `callMatcher` says how many matching calls are expected, `times(1)` by default. A failed check reports where
/// `verify` was called, and lists the member's actual calls.
public func verify<M: Mock>(_ mock: M, _ callMatcher: CallMatcher = times(1), fileID: String = #fileID, filePath: StaticString = #filePath, line: Int = #line, column: Int = #column) -> M.CuckooVerification {
    return mock.cuckooVerificationProxy(callMatcher, sourceLocation: (fileID, filePath, line, column))
}

/// Clears the stubs and the recorded calls of `mocks`.
public func reset(_ mocks: any HasMockManager...) {
    mocks.forEach { mock in
        mock.cuckooManager.reset()
    }
}

/// Clears the stubs of `mocks`, keeping their recorded calls. The mocks may be of different types.
public func clearStubs(_ mocks: any Mock...) {
    mocks.forEach { mock in
        mock.cuckooManager.clearStubs()
    }
}

/// Clears the recorded calls of `mocks`, keeping their stubs. The mocks may be of different types.
public func clearInvocations(_ mocks: any Mock...) {
    mocks.forEach { mock in
        mock.cuckooManager.clearInvocations()
    }
}

/// Fails if `mocks`, which may be of different types, received any call that no earlier `verify` checked.
///
/// A mock of a global-actor type, such as a `@MainActor` protocol, is checked only on that actor, where its
/// calls' arguments live: called elsewhere, it records a failure instead of reading them. Leave `isolation` out. A
/// nonisolated helper function that calls it runs it as nonisolated, even when its caller is on the actor: isolate
/// the helper to the mock's actor, or give it an `isolation: isolated (any Actor)? = #isolation` parameter and pass
/// it on. The main actor is recognized on the main thread either way.
public func verifyNoMoreInteractions(
    _ mocks: any Mock...,
    fileID: String = #fileID,
    filePath: StaticString = #filePath,
    line: Int = #line,
    column: Int = #column,
    isolation: isolated (any Actor)? = #isolation
) {
    mocks.forEach { mock in
        mock.cuckooManager.verifyNoMoreInteractions(
            (fileID, filePath, line, column),
            mockType: type(of: mock),
            globalActor: type(of: mock).cuckooGlobalActor,
            caller: isolation
        )
    }
}

/// Stubs a mock type's static or class members, in the current ``StaticStubs`` scope: `stub(MockClock.self) { stub in … }`.
public func stub<M: StaticMock>(_ type: M.Type, block: (M.CuckooStaticStubbing) -> Void) {
    block(M.CuckooStaticStubbing(manager: M.cuckooStaticManager))
}

/// Returns a proxy that checks the calls a mock type's static or class members received, in the current
/// ``StaticStubs`` scope.
public func verify<M: StaticMock>(_ type: M.Type, _ callMatcher: CallMatcher = times(1), fileID: String = #fileID, filePath: StaticString = #filePath, line: Int = #line, column: Int = #column) -> M.CuckooStaticVerification {
    M.CuckooStaticVerification(manager: M.cuckooStaticManager, callMatcher: callMatcher, sourceLocation: (fileID, filePath, line, column))
}

/// Clears the stubs and recorded calls of mock types' static members, in the current ``StaticStubs`` scope.
public func reset(_ types: any StaticMock.Type...) {
    types.forEach { type in
        type.cuckooStaticManager.reset()
    }
}

/// Clears the stubs of mock types' static members, keeping their recorded calls, in the current ``StaticStubs``
/// scope.
public func clearStubs(_ types: any StaticMock.Type...) {
    types.forEach { type in
        type.cuckooStaticManager.clearStubs()
    }
}

/// Clears the recorded calls of mock types' static members, keeping their stubs, in the current ``StaticStubs``
/// scope.
public func clearInvocations(_ types: any StaticMock.Type...) {
    types.forEach { type in
        type.cuckooStaticManager.clearInvocations()
    }
}

/// Fails if mock types' static members received any call that no earlier `verify` checked, in the current
/// ``StaticStubs`` scope. Like the instance form, a global-actor mock type is checked only on its actor.
public func verifyNoMoreInteractions(
    _ types: any StaticMock.Type...,
    fileID: String = #fileID,
    filePath: StaticString = #filePath,
    line: Int = #line,
    column: Int = #column,
    isolation: isolated (any Actor)? = #isolation
) {
    types.forEach { type in
        type.cuckooStaticManager.verifyNoMoreInteractions(
            (fileID, filePath, line, column),
            mockType: type,
            globalActor: type.cuckooGlobalActor,
            caller: isolation
        )
    }
}
