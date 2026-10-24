import Testing
import Cuckoo
@testable import CuckooMocks
@testable import CuckooTestSources

/// Hammers one mock from many tasks at once. Run under the Thread Sanitizer (`swift test --sanitize=thread`)
/// to check that stubbing, calling, verifying and clearing don't race.
struct ConcurrencyStressTests {
    static let iterations = 1_000

    @Test
    func concurrentCallsAreAllRecorded() async {
        let mock = MockConcurrentCounter()
        stub(mock) { stub in
            when(stub.count(characters: any())).thenReturn(1)
        }

        let total = await withTaskGroup(of: Int.self) { group in
            for index in 0..<Self.iterations {
                group.addTask {
                    mock.count(characters: "\(index)")
                }
            }
            return await group.reduce(0, +)
        }

        #expect(total == Self.iterations)
        verify(mock, times(Self.iterations)).count(characters: any())
    }

    @Test
    func stubbingCallingAndVerifyingInterleave() async {
        let mock = MockConcurrentCounter()
        stub(mock) { stub in
            when(stub.count(characters: any())).thenReturn(0)
        }

        await withTaskGroup(of: Void.self) { group in
            for index in 0..<Self.iterations {
                group.addTask {
                    switch index % 4 {
                    case 0:
                        // A later stub for one specific argument overrides the catch-all.
                        stub(mock) { stub in
                            when(stub.count(characters: "\(index)")).thenReturn(index)
                        }
                    case 1:
                        _ = mock.count(characters: "\(index)")
                    case 2:
                        verify(mock, atLeast(0)).count(characters: any())
                    default:
                        _ = mock.count(characters: "\(index - 3)")
                    }
                }
            }
        }

        // Every stub registered above answers its own argument.
        for index in stride(from: 0, to: Self.iterations, by: 4) {
            #expect(mock.count(characters: "\(index)") == index)
        }
    }

    @Test
    func clearingWhileCallingDoesNotCrash() async {
        let mock = MockConcurrentCounter()

        // Unstubbed calls fail, and so does verifyNoMoreInteractions whenever a call slipped in since the last
        // clear. Neither matters here.
        let ignoreFailures = CuckooConfiguration(failureHandler: { _, _ in })
        await CuckooConfiguration.$current.withValue(ignoreFailures) {
            await withTaskGroup(of: Void.self) { group in
                for index in 0..<Self.iterations {
                    group.addTask {
                        switch index % 3 {
                        case 0:
                            _ = mock.count(characters: "\(index)")
                        case 1:
                            clearInvocations(mock)
                        default:
                            verifyNoMoreInteractions(mock)
                        }
                    }
                }
            }
        }
    }

    @Test
    func sequentialStubAnswersAreHandedOutOnce() async {
        let mock = MockConcurrentCounter()
        let answers = Array(1...Self.iterations)
        stub(mock) { stub in
            when(stub.count(characters: any())).thenReturn(inOrder: answers)
        }

        let received = await withTaskGroup(of: Int.self) { group in
            for _ in 0..<Self.iterations {
                group.addTask {
                    mock.count(characters: "")
                }
            }
            return await group.reduce(into: [Int]()) { $0.append($1) }
        }

        // Each queued answer goes to exactly one call.
        #expect(received.sorted() == answers)
    }
}
