import Testing
@testable import Cuckoo
@testable import CuckooMocks
@testable import CuckooTestSources

/// How a failed `verify` leaves its calls.
struct MockSetupTest {
    @Test
    func aFailedVerifyLeavesItsCallsUnverified() {
        let mock = MockTestedProtocol()
        stub(mock) { stub in
            when(stub.noReturn()).thenDoNothing()
        }
        mock.noReturn()

        let failures = Locked<[String]>([])
        let collect = CuckooConfiguration(failureHandler: { message, _ in failures.withLock { $0.append(message) } })
        CuckooConfiguration.$current.withValue(collect) {
            verify(mock, times(2)).noReturn()
            verifyNoMoreInteractions(mock)
        }

        let messages = failures.withLock { $0 }
        #expect(messages.count == 2)
        #expect(messages.first?.hasPrefix("Wanted 2 times but invoked 1 times.") == true)
        #expect(messages.last?.hasPrefix("No more interactions wanted but some found:") == true)
    }

    @Test
    func aPassingVerifyMarksItsCallsVerified() {
        let mock = MockTestedProtocol()
        stub(mock) { stub in
            when(stub.noReturn()).thenDoNothing()
        }
        mock.noReturn()

        verify(mock).noReturn()
        verifyNoMoreInteractions(mock)
    }
}
