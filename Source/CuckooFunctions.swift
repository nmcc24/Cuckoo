/// Stubs members of `mock`.
///
/// The block receives the mock's stubbing proxy: `stub(mock) { stub in when(stub.greet(any())).thenReturn("Hi") }`.
/// Call it as often as needed; a newer stub of the same call takes precedence over older ones.
public func stub<M: Mock>(_ mock: M, block: (M.Stubbing) -> Void) {
    block(mock.getStubbingProxy())
}

/// Marks the member being stubbed inside a ``stub(_:block:)-(M,_)`` block, for example `when(stub.count.get)`.
///
/// It returns `function` unchanged today, but write it anyway: later versions may rely on it.
public func when<F: BaseStubFunctionTrait>(_ function: F) -> F {
    return function
}

/// Returns a proxy that checks the calls `mock` received, for example `verify(mock, times(2)).greet("Ann")`.
///
/// `callMatcher` says how many matching calls are expected, `times(1)` by default. A failed check reports where
/// `verify` was called, and lists the member's actual calls.
public func verify<M: Mock>(_ mock: M, _ callMatcher: CallMatcher = times(1), fileID: String = #fileID, filePath: StaticString = #filePath, line: Int = #line, column: Int = #column) -> M.Verification {
    return mock.getVerificationProxy(callMatcher, sourceLocation: (fileID, filePath, line, column))
}

/// Clears the stubs and the recorded calls of `mocks`.
public func reset(_ mocks: any HasMockManager...) {
    mocks.forEach { mock in
        mock.cuckoo_manager.reset()
    }
}

/// Clears the stubs of `mocks`, keeping their recorded calls.
public func clearStubs<M: Mock>(_ mocks: M...) {
    mocks.forEach { mock in
        mock.cuckoo_manager.clearStubs()
    }
}

/// Clears the recorded calls of `mocks`, keeping their stubs.
public func clearInvocations<M: Mock>(_ mocks: M...) {
    mocks.forEach { mock in
        mock.cuckoo_manager.clearInvocations()
    }
}

/// Fails if `mocks` received any call that no earlier `verify` checked.
public func verifyNoMoreInteractions<M: Mock>(_ mocks: M..., fileID: String = #fileID, filePath: StaticString = #filePath, line: Int = #line, column: Int = #column) {
    mocks.forEach { mock in
        mock.cuckoo_manager.verifyNoMoreInteractions((fileID, filePath, line, column))
    }
}

/// Stubs a mock type's static or class members, in the current ``StaticStubs`` scope: `stub(MockClock.self) { stub in … }`.
public func stub<M: StaticMock>(_ type: M.Type, block: (M.StaticStubbing) -> Void) {
    block(M.StaticStubbing(manager: M.cuckoo_staticManager))
}

/// Returns a proxy that checks the calls a mock type's static or class members received, in the current
/// ``StaticStubs`` scope.
public func verify<M: StaticMock>(_ type: M.Type, _ callMatcher: CallMatcher = times(1), fileID: String = #fileID, filePath: StaticString = #filePath, line: Int = #line, column: Int = #column) -> M.StaticVerification {
    M.StaticVerification(manager: M.cuckoo_staticManager, callMatcher: callMatcher, sourceLocation: (fileID, filePath, line, column))
}

/// Clears the stubs and recorded calls of mock types' static members, in the current ``StaticStubs`` scope.
public func reset(_ types: any StaticMock.Type...) {
    types.forEach { type in
        type.cuckoo_staticManager.reset()
    }
}

/// Fails if a mock type's static members received any call that no earlier `verify` checked, in the current
/// ``StaticStubs`` scope.
public func verifyNoMoreInteractions<M: StaticMock>(_ type: M.Type, fileID: String = #fileID, filePath: StaticString = #filePath, line: Int = #line, column: Int = #column) {
    M.cuckoo_staticManager.verifyNoMoreInteractions((fileID, filePath, line, column))
}
