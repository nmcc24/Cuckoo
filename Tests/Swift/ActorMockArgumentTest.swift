import Testing
@testable import Cuckoo
@testable import CuckooMocks
@testable import CuckooTestSources

/// Actor mocks of members that take non-`Sendable` arguments, and actor mocks' lack of a default implementation.
struct ActorMockArgumentTests {
    @Test
    func thenClosuresReceiveNonSendableArguments() async {
        let mock = MockLedgerStore()
        stub(mock) { stub in
            when(stub.record(any(), in: any())).then { _, entry, ledger in
                ledger.entries.append(entry)
                return ledger.entries.count
            }
            when(stub.archive(any())).then { _, ledger in
                ledger.entries.count + 10
            }
            when(stub[any()].get).then { _, ledger in
                "\(ledger.entries.count) entries"
            }
            when(stub.ledger.set(any())).then { _, ledger in
                ledger.entries.append("set")
            }
        }

        #expect(await mock.record("first", in: Ledger()) == 1)
        #expect(await mock.archive(Ledger()) == 10)
        #expect(await mock.read(Ledger()) == "0 entries")
        await mock.setLedger(Ledger())

        verify(mock).record("first", in: any())
        verify(mock).archive(any())
        verify(mock)[any()].get()
        verify(mock).ledger.set(any())
    }

    @Test
    func actorMocksRefuseADefaultImplementation() async {
        let failures = Locked<[String]>([])
        let mock = MockLedgerStore()
        CuckooConfiguration.$current.withValue(CuckooConfiguration(failureHandler: { message, _ in failures.withLock { $0.append(message) } })) {
            mock.enableDefaultImplementation(RealLedgerStore())
        }
        stub(mock) { stub in
            when(stub.archive(any())).thenReturn(3)
        }

        #expect(failures.withLock { $0 } == ["Actor mocks have no default implementation. Stub their members instead."])
        #expect(await mock.archive(Ledger()) == 3)
    }
}

// A subscript can't take a `sending` argument, so a non-Sendable key reaches it from inside the actor.
private extension LedgerStore {
    func read(_ ledger: sending Ledger) -> String {
        self[ledger]
    }

    func setLedger(_ ledger: sending Ledger) {
        self.ledger = ledger
    }
}
