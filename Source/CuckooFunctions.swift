/// Starts the stubbing for the given mock. Can be used multiple times.
public func stub<M: Mock>(_ mock: M, block: (M.Stubbing) -> Void) {
    block(mock.getStubbingProxy())
}

/// Used in stubbing. Currently only returns passed function but this may change in the future so it is not recommended to omit it.
public func when<F: BaseStubFunctionTrait>(_ function: F) -> F {
    return function
}

/// Creates object used for verification of calls.
public func verify<M: Mock>(_ mock: M, _ callMatcher: CallMatcher = times(1), file: StaticString = #file, fileID: String = #fileID, filePath: String = #filePath, line: Int = #line, column: Int = #column) -> M.Verification {
    return mock.getVerificationProxy(callMatcher, sourceLocation: (file, fileID, filePath, line, column))
}

/// Clears all invocations and stubs of mocks.
public func reset(_ mocks: any HasMockManager...) {
    mocks.forEach { mock in
        mock.cuckoo_manager.reset()
    }
}

/// Clears all stubs of mocks.
public func clearStubs<M: Mock>(_ mocks: M...) {
    mocks.forEach { mock in
        mock.cuckoo_manager.clearStubs()
    }
}

/// Clears all invocations of mocks.
public func clearInvocations<M: Mock>(_ mocks: M...) {
    mocks.forEach { mock in
        mock.cuckoo_manager.clearInvocations()
    }
}

/// Checks if there are no more uverified calls.
public func verifyNoMoreInteractions<M: Mock>(_ mocks: M..., file: StaticString = #file, fileID: String = #fileID, filePath: String = #filePath, line: Int = #line, column: Int = #column) {
    mocks.forEach { mock in
        mock.cuckoo_manager.verifyNoMoreInteractions((file, fileID, filePath, line, column))
    }
}

/// Starts the stubbing of a mock type's static members, in the current `StaticStubs` scope.
public func stub<M: StaticMock>(_ type: M.Type, block: (M.StaticStubbing) -> Void) {
    block(M.StaticStubbing(manager: M.cuckoo_staticManager))
}

/// Creates object used for verification of a mock type's static member calls, in the current `StaticStubs` scope.
public func verify<M: StaticMock>(_ type: M.Type, _ callMatcher: CallMatcher = times(1), file: StaticString = #file, fileID: String = #fileID, filePath: String = #filePath, line: Int = #line, column: Int = #column) -> M.StaticVerification {
    M.StaticVerification(manager: M.cuckoo_staticManager, callMatcher: callMatcher, sourceLocation: (file, fileID, filePath, line, column))
}

/// Clears all invocations and stubs of mock types' static members, in the current `StaticStubs` scope.
public func reset(_ types: any StaticMock.Type...) {
    types.forEach { type in
        type.cuckoo_staticManager.reset()
    }
}

/// Checks that a mock type's static members have no more unverified calls, in the current `StaticStubs` scope.
public func verifyNoMoreInteractions<M: StaticMock>(_ type: M.Type, file: StaticString = #file, fileID: String = #fileID, filePath: String = #filePath, line: Int = #line, column: Int = #column) {
    M.cuckoo_staticManager.verifyNoMoreInteractions((file, fileID, filePath, line, column))
}
