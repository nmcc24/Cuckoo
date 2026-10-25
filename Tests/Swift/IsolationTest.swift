import Testing
import Cuckoo
@testable import CuckooMocks
@testable import CuckooTestSources

@TestDatabaseActor
private final class SavedValues {
    var values: [String] = []
}

/// Stubbing and verifying mocks of actor-isolated and `Sendable` types from Swift 6 code.
struct IsolationTests {
    enum TestError: Error {
        case failed
    }

    @Test @MainActor
    func mainActorProtocolClosuresRunOnTheMainActor() async throws {
        let mock = MockMainActorService()
        let viewModel = RecordingViewModel()
        stub(mock) { stub in
            when(stub.load(id: any())).then { id in
                // A non-`Sendable` MainActor object, used directly: the closure is MainActor-isolated.
                viewModel.events.append("load \(id)")
                return "item \(id)"
            }
            when(stub.refresh()).then {
                viewModel.events.append("refresh")
            }
            when(stub.title.get).thenReturn("Title")
            when(stub.title.set(any())).then { newValue in
                viewModel.events.append("title \(newValue)")
            }
        }

        #expect(mock.load(id: 7) == "item 7")
        try await mock.refresh()
        #expect(mock.title == "Title")
        mock.title = "New"

        #expect(viewModel.events == ["load 7", "refresh", "title New"])
        verify(mock).load(id: 7)
        verify(mock).refresh()
        verify(mock).title.set("New")
    }

    @Test @MainActor
    func mainActorProtocolThenReturnTakesNonSendableValues() {
        let mock = MockMainActorService()
        stub(mock) { stub in
            when(stub.load(id: 1)).thenReturn("one", "uno")
        }

        #expect(mock.load(id: 1) == "one")
        #expect(mock.load(id: 1) == "uno")
        verify(mock, times(2)).load(id: 1)
    }

    @Test @MainActor
    func mainActorProtocolThrows() async {
        let mock = MockMainActorService()
        stub(mock) { stub in
            when(stub.refresh()).thenThrow(TestError.failed)
        }

        await #expect(throws: TestError.self) {
            try await mock.refresh()
        }
    }

    @Test @MainActor
    func mainActorClass() async {
        let mock = MockMainActorViewModel()
        let viewModel = RecordingViewModel()
        stub(mock) { stub in
            when(stub.select(index: any())).then { index in
                viewModel.events.append("select \(index)")
                return index > 0
            }
            when(stub.reload()).then {
                viewModel.events.append("reload")
            }
            when(stub.state.get).thenReturn("ready")
        }

        #expect(mock.select(index: 2))
        #expect(!mock.select(index: 0))
        await mock.reload()
        #expect(mock.state == "ready")

        #expect(viewModel.events == ["select 2", "select 0", "reload"])
        verify(mock, times(2)).select(index: any())
        verify(mock).reload()
    }

    @Test @MainActor
    func mainActorClassSpiesOnTheSuperclass() {
        let mock = MockMainActorViewModel().withEnabledSuperclassSpy()

        #expect(mock.select(index: 3))
        verify(mock).select(index: 3)
    }

    @Test @TestDatabaseActor
    func customGlobalActorProtocol() {
        let mock = MockDatabaseStore()
        let saved = SavedValues()
        stub(mock) { stub in
            when(stub.save(any())).then { value in
                saved.values.append(value)
            }
            when(stub.all()).then {
                saved.values
            }
        }

        mock.save("a")
        mock.save("b")

        #expect(mock.all() == ["a", "b"])
        verify(mock, times(2)).save(any())
        verify(mock).all()
    }

    @Test
    func actorProtocolClosuresReceiveTheIsolatedMock() async throws {
        let mock = MockCounterStore()
        stub(mock) { stub in
            when(stub.count.get).thenReturn(10)
            when(stub.increment(by: any())).then { mock, amount in
                // Isolated to the mock, so its members are reachable without `await`.
                mock.count + amount
            }
            when(stub.fetch(id: 1)).then { _, id in
                "item \(id)"
            }
            when(stub.fetch(id: 2)).thenThrow(TestError.failed)
        }

        #expect(await mock.increment(by: 5) == 15)
        #expect(try await mock.fetch(id: 1) == "item 1")
        await #expect(throws: TestError.self) {
            try await mock.fetch(id: 2)
        }

        verify(mock).increment(by: 5)
        verify(mock, times(2)).fetch(id: any())
        verify(mock).count.get()
    }

    @Test
    func actorProtocolCalledFromManyTasks() async {
        let mock = MockCounterStore()
        stub(mock) { stub in
            when(stub.increment(by: any())).then { _, amount in
                amount
            }
        }

        let total = await withTaskGroup(of: Int.self) { group in
            for _ in 0..<100 {
                group.addTask {
                    await mock.increment(by: 1)
                }
            }
            return await group.reduce(0, +)
        }

        #expect(total == 100)
        verify(mock, times(100)).increment(by: 1)
    }

    @Test
    func sendableProtocolIsUsableFromOtherTasks() async {
        let mock = MockSendableService()
        stub(mock) { stub in
            when(stub.value(for: any())).then { key in
                key.count
            }
            when(stub.load()).thenReturn("loaded")
        }

        let value = await Task.detached {
            mock.value(for: "four")
        }.value

        #expect(value == 4)
        #expect(await mock.load() == "loaded")
        verify(mock).value(for: "four")
        verify(mock).load()
    }
}
