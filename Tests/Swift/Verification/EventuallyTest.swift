import Testing
@testable import Cuckoo
@testable import CuckooMocks
@testable import CuckooTestSources

struct EventuallyTests {
    private func stubbedCounter() -> MockConcurrentCounter {
        let mock = MockConcurrentCounter()
        stub(mock) { stub in
            when(stub.count(characters: any())).thenReturn(1)
        }
        return mock
    }

    @Test
    func passesOnceACallFromAnotherTaskArrives() async {
        let mock = stubbedCounter()

        let task = Task {
            try? await Task.sleep(for: .milliseconds(50))
            _ = mock.count(characters: "a")
        }

        let messages = await collectingMessages {
            await eventually(timeout: .seconds(10)) {
                verify(mock).count(characters: "a")
            }
        }
        #expect(messages.isEmpty)
        await task.value
    }

    @Test
    func returnsAtOnceWhenTheBlockAlreadyPasses() async {
        let mock = stubbedCounter()
        _ = mock.count(characters: "a")
        let clock = ContinuousClock()

        let elapsed = await clock.measure {
            await eventually(timeout: .seconds(10)) {
                verify(mock).count(characters: "a")
            }
        }
        #expect(elapsed < .seconds(5))
    }

    @Test
    func reportsTheLastRunsFailuresOnceAfterTheTimeout() async {
        let mock = stubbedCounter()

        let messages = await collectingMessages {
            await eventually(timeout: .milliseconds(50)) {
                verify(mock).count(characters: "a")
            }
        }
        #expect(messages == ["Still failing after 0.05 seconds: Wanted 1 time but not invoked.\nThe mock received no calls."])
    }

    @Test
    func reportsEveryFailureOfTheLastRun() async {
        let mock = stubbedCounter()

        let messages = await collectingMessages {
            await eventually(timeout: .milliseconds(20)) {
                verify(mock).count(characters: "a")
                verify(mock).count(characters: "b")
            }
        }
        #expect(messages.count == 2)
    }

    @Test
    func stopsWaitingWhenCancelled() async {
        let mock = stubbedCounter()
        let clock = ContinuousClock()

        let elapsed = await clock.measure {
            let messages = await collectingMessages {
                await withTaskGroup(of: Void.self) { group in
                    group.addTask {
                        await eventually(timeout: .seconds(60)) {
                            verify(mock).count(characters: "a")
                        }
                    }
                    group.cancelAll()
                }
            }
            #expect(messages.count == 1)
        }
        #expect(elapsed < .seconds(30))
    }

    /// A task the block starts keeps `eventually`'s failure handler. A failure it records after the block has
    /// returned still reaches the test.
    @Test
    func reportsAFailureFromATaskTheBlockStarted() async {
        let mock = MockConcurrentCounter()
        let started = Locked<Task<Void, Never>?>(nil)
        // The task calls the mock only once `eventually` has returned, so its failure always arrives late.
        let returned = Locked(false)

        let messages = await collectingMessages {
            await eventually(timeout: .seconds(10)) {
                started.withLock { task in
                    guard task == nil else {
                        return
                    }
                    task = Task {
                        while !returned.withLock({ $0 }) {
                            await Task.yield()
                        }
                        _ = mock.count(characters: "a")
                    }
                }
            }
            returned.withLock { $0 = true }
            await started.withLock { $0 }?.value
        }
        #expect(messages.count == 1)
        #expect(messages.first?.contains("count(characters:") == true)
    }

    /// The failures `body` reports, without failing the test.
    private func collectingMessages(_ body: () async -> Void) async -> [String] {
        let messages = Locked<[String]>([])
        var configuration = CuckooConfiguration.current
        configuration.failureHandler = { failure in
            messages.withLock { $0.append(failure.message) }
        }
        await CuckooConfiguration.$current.withValue(configuration) {
            await body()
        }
        return messages.withLock { $0 }
    }
}
