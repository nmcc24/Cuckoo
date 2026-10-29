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
        #expect(messages == ["Still failing after 0.05 seconds: Wanted 1 times but not invoked."])
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

    /// The failures `body` reports, without failing the test.
    private func collectingMessages(_ body: () async -> Void) async -> [String] {
        let messages = Locked<[String]>([])
        var configuration = CuckooConfiguration.current
        configuration.failureHandler = { message, _ in
            messages.withLock { $0.append(message) }
        }
        await CuckooConfiguration.$current.withValue(configuration) {
            await body()
        }
        return messages.withLock { $0 }
    }
}
