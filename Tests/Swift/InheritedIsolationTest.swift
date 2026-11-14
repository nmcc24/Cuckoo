import Testing
import Cuckoo
@testable import CuckooMocks
@testable import CuckooTestSources

@TestDatabaseActor
private final class ArchiveLog {
    var entries: [String] = []
}

/// A protocol that refines an isolated, actor or `Sendable` protocol, and states nothing itself, is mocked as its
/// parent is: its own and its inherited members alike.
struct InheritedIsolationTests {
    @Test @MainActor
    func mainActorParentIsolatesTheChildsMembers() {
        let mock = MockMainActorDetailService()
        let viewModel = RecordingViewModel()
        stub(mock) { stub in
            when(stub.detail(id: any())).then { id in
                // A non-`Sendable` MainActor object, used directly: the closure is MainActor-isolated.
                viewModel.events.append("detail \(id)")
                return "detail \(id)"
            }
            when(stub.load(id: any())).then { id in
                viewModel.events.append("load \(id)")
                return "item \(id)"
            }
        }

        #expect(mock.detail(id: 1) == "detail 1")
        #expect(mock.load(id: 2) == "item 2")
        #expect(viewModel.events == ["detail 1", "load 2"])
        verify(mock).detail(id: 1)
        verify(mock).load(id: 2)
    }

    @Test @TestDatabaseActor
    func customGlobalActorParentIsolatesTheChildsMembers() {
        let mock = MockDatabaseArchive()
        let log = ArchiveLog()
        stub(mock) { stub in
            when(stub.archive()).then {
                log.entries.append("archive")
                return 3
            }
            when(stub.save(any())).then { value in
                log.entries.append("save \(value)")
            }
        }

        mock.save("a")
        #expect(mock.archive() == 3)
        #expect(log.entries == ["save a", "archive"])
        verify(mock).archive()
        verify(mock).save("a")
    }

    @Test
    func actorParentMakesTheChildsMockAnActor() async {
        let mock = MockLimitedCounterStore()
        stub(mock) { stub in
            when(stub.count.get).thenReturn(4)
            when(stub.reset()).then { mock in
                // Isolated to the child's mock, so its inherited members are reachable without `await`.
                mock.count
            }
            when(stub.increment(by: any())).then { mock, amount in
                mock.count + amount
            }
        }

        #expect(await mock.reset() == 4)
        #expect(await mock.increment(by: 1) == 5)
        verify(mock).reset()
        verify(mock).increment(by: 1)
    }

    @Test
    func sendableParentMakesTheChildsMockSendable() async {
        let mock = MockSendableCache()
        stub(mock) { stub in
            when(stub.store(any(), for: any())).thenDoNothing()
            when(stub.value(for: any())).thenReturn(9)
        }

        let value = await Task.detached {
            mock.store(1, for: "one")
            return mock.value(for: "one")
        }.value

        #expect(value == 9)
        verify(mock).store(1, for: "one")
        verify(mock).value(for: "one")
    }
}
