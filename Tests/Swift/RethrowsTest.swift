import Testing
@testable import Cuckoo
@testable import CuckooMocks
@testable import CuckooTestSources

/// A rethrowing member answers an unstubbed call with a default value, never by throwing: a caller that passes a
/// closure that doesn't throw has no `try`, so an error escaping the call would crash the test process.
struct RethrowsTest {
    private struct Failure: Error, Equatable {}

    private func recordingFailures(_ body: () -> Void) -> [String] {
        let failures = Locked<[String]>([])
        CuckooConfiguration.$current.withValue(CuckooConfiguration(failureHandler: { message, _ in failures.withLock { $0.append(message) } })) {
            body()
        }
        return failures.withLock { $0 }
    }

    @Test
    func unstubbedCallWithANonThrowingClosureRecordsAFailureAndReturnsTheDefault() {
        let mock = MockRethrowingService()

        let failures = recordingFailures {
            #expect(mock.transform(1, using: { $0 + 1 }) == 0)
        }

        #expect(failures.count == 1)
        #expect(failures.first?.hasPrefix("No stub for method `transform(") == true)
    }

    @Test
    func unstubbedAsyncCallWithANonThrowingClosureRecordsAFailureAndReturnsTheDefault() async {
        let mock = MockRethrowingService()
        let failures = Locked<[String]>([])

        await CuckooConfiguration.$current.withValue(CuckooConfiguration(failureHandler: { message, _ in failures.withLock { $0.append(message) } })) {
            #expect(await mock.transformAsync(1, using: { $0 + 1 }) == 0)
        }

        #expect(failures.withLock { $0.count } == 1)
    }

    @Test
    func unstubbedCallWithAThrowingClosureReturnsTheDefaultToo() throws {
        let mock = MockRethrowingService()

        let failures = recordingFailures {
            #expect((try? mock.transform(1, using: { _ in throw Failure() })) == 0)
        }

        #expect(failures.count == 1)
    }

    @Test
    func stubbedCallStillAnswersFromItsStub() throws {
        let mock = MockRethrowingService()
        stub(mock) { stub in
            when(stub.transform(any(), using: anyThrowingClosure())).thenReturn(7)
        }

        #expect(mock.transform(1, using: { $0 }) == 7)
        verify(mock).transform(equal(to: 1), using: anyThrowingClosure())
    }

    @Test
    func thenThrowReachesACallerWhoseClosureThrows() {
        let mock = MockRethrowingService()
        stub(mock) { stub in
            when(stub.transform(any(), using: anyThrowingClosure())).thenThrow(Failure())
        }

        #expect(throws: Failure.self) {
            try mock.transform(1, using: { _ in throw Failure() })
        }
    }
}
