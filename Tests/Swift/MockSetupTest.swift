import Testing
@testable import Cuckoo
@testable import CuckooMocks
@testable import CuckooTestSources

/// Enabling the superclass spy or a default implementation, and how a failed `verify` leaves its calls.
struct MockSetupTest {
    @Test
    func replacingTheDefaultImplementationAfterACallIsAllowed() {
        let mock = MockTestedProtocol()
        mock.enableDefaultImplementation(TestedProtocolStub())
        _ = mock.count(characters: "a")

        let failure = TestUtils.catchCuckooFail {
            mock.enableDefaultImplementation(TestedProtocolStub())
        }

        #expect(failure == nil)
        #expect(mock.count(characters: "b") == 0)
    }

    @Test
    func superclassSpyOnAProtocolMockIsAFailureNotACrash() {
        var mock: MockTestedProtocol?
        let failure = TestUtils.catchCuckooFail {
            mock = createMock(MockTestedProtocol.self) { builder, _ in
                builder.enableSuperclassSpy()
                return MockTestedProtocol()
            }
        }

        #expect(failure?.hasPrefix("A protocol mock has no superclass to spy on.") == true)
        // The spy wasn't enabled, so the call is unstubbed rather than a crash.
        let unstubbed = TestUtils.catchCuckooFail {
            _ = mock?.count(characters: "a")
        }
        #expect(unstubbed?.hasPrefix("No stub for method `count(characters") == true)
    }

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
        #expect(messages.first?.hasPrefix("Wanted 2 times but invoked 1 time.") == true)
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
