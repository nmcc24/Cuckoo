import Testing
@testable import Cuckoo
@testable import CuckooMocks
@testable import CuckooTestSources

struct CuckooFunctionsTest {
    @Test
    func testReset() {
        let mock = MockTestedClass().withEnabledSuperclassSpy()
        stub(mock) { mock in
            when(mock.count(characters: any())).thenReturn(10)
        }
        #expect(mock.count(characters: "a") == 10)
        
        reset(mock)
        
        verify(mock, never()).count(characters: "a")
        #expect(mock.count(characters: "a") == 1)
        verify(mock).count(characters: "a")
    }

    @Test
    func testClearStubs() {
        let mock = MockTestedClass().withEnabledSuperclassSpy()
        stub(mock) { mock in
            when(mock.count(characters: any())).thenReturn(10)
        }
        #expect(mock.count(characters: "a") == 10)

        clearStubs(mock)

        verify(mock).count(characters: "a")
        #expect(mock.count(characters: "a") == 1)
        verify(mock, times(2)).count(characters: "a")
    }

    @Test
    func testClearInvocations() {
        let mock = MockTestedClass()
        stub(mock) { mock in
            when(mock.count(characters: any())).thenReturn(10)
        }
        #expect(mock.count(characters: "a") == 10)

        clearInvocations(mock)

        verify(mock, never()).count(characters: "a")
        #expect(mock.count(characters: "a") == 10)
        verify(mock).count(characters: "a")
    }

    enum Clearing: CaseIterable, Sendable { case reset, invocations, stubs }

    /// Clearing releases the recorded arguments and stubs outside the manager's lock, so a released value whose
    /// `deinit` reads the mock doesn't deadlock.
    @Test(arguments: Clearing.allCases)
    func clearingReleasesValuesOutsideTheLock(clearing: Clearing) {
        final class ReadsMockOnDeinit {
            let mock: MockTestedProtocol
            let released: Locked<Bool>
            init(mock: MockTestedProtocol, released: Locked<Bool>) {
                self.mock = mock
                self.released = released
            }
            deinit {
                verify(mock, never()).noReturn()
                released.withLock { $0 = true }
            }
        }
        let mock = MockTestedProtocol()
        let stubReleased = Locked(false)
        let callReleased = Locked(false)
        do {
            let inStub = ReadsMockOnDeinit(mock: mock, released: stubReleased)
            let inCall = ReadsMockOnDeinit(mock: mock, released: callReleased)
            stub(mock) { mock in
                when(mock.withEscape(any(), action: any())).then { _, _ in _ = inStub }
            }
            mock.withEscape("a") { _ in _ = inCall }
        }

        switch clearing {
        case .reset: reset(mock)
        case .invocations: clearInvocations(mock)
        case .stubs: clearStubs(mock)
        }

        #expect(stubReleased.withLock { $0 } == (clearing != .invocations))
        #expect(callReleased.withLock { $0 } == (clearing != .stubs))
    }

    @Test
    func testVerifyNoMoreInteractions() {
        let mock = MockTestedClass()
        stub(mock) { mock in
            when(mock.noReturn()).thenDoNothing()
        }

        mock.noReturn()
        verify(mock).noReturn()

        verifyNoMoreInteractions(mock)
    }

    @Test
    func clearingAndCheckingMocksOfDifferentTypes() {
        let classMock = MockTestedClass()
        let protocolMock = MockTestedProtocol()
        stub(classMock) { stub in
            when(stub.noReturn()).thenDoNothing()
        }
        stub(protocolMock) { stub in
            when(stub.noReturn()).thenDoNothing()
        }
        classMock.noReturn()
        protocolMock.noReturn()

        let unverified = TestUtils.catchCuckooFail {
            verifyNoMoreInteractions(classMock, protocolMock)
        }
        #expect(unverified != nil)

        clearInvocations(classMock, protocolMock)
        verifyNoMoreInteractions(classMock, protocolMock)

        clearStubs(classMock, protocolMock)
        let unstubbed = TestUtils.catchCuckooFail {
            protocolMock.noReturn()
        }
        #expect(unstubbed != nil)
    }
}
