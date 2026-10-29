import Testing
@testable import Cuckoo
@testable import CuckooMocks
@testable import CuckooTestSources

struct InOrderTests {
    private let database = MockTestedProtocol()
    private let cache = MockTestedClass()

    init() {
        stub(database) { stub in
            when(stub.noReturn()).thenDoNothing()
            when(stub.count(characters: any())).thenReturn(0)
        }
        stub(cache) { stub in
            when(stub.noReturn()).thenDoNothing()
            when(stub.count(characters: any())).thenReturn(0)
        }
    }

    @Test
    func passesWhenCallsAcrossMocksCameInOrder() {
        database.noReturn()
        _ = cache.count(characters: "a")
        _ = database.count(characters: "b")

        let messages = collectingMessages {
            inOrder {
                verify(database).noReturn()
                verify(cache).count(characters: "a")
                verify(database).count(characters: "b")
            }
        }
        #expect(messages.isEmpty)
    }

    @Test
    func failsWhenCallsCameInAnotherOrder() {
        _ = cache.count(characters: "a")
        database.noReturn()

        let messages = collectingMessages {
            inOrder {
                verify(database).noReturn()
                verify(cache).count(characters: "a")
            }
        }
        #expect(messages.count == 1)
        #expect(messages.first?.hasPrefix("Wanted 1 times in order but invoked 0 times after the previous verification (1 times in all).") == true)
        #expect(messages.first?.contains("→ count(characters: \"a\")") == false)
    }

    @Test
    func allowsOtherCallsInBetween() {
        database.noReturn()
        cache.noReturn()
        _ = database.count(characters: "b")

        let messages = collectingMessages {
            inOrder {
                verify(database).noReturn()
                verify(database).count(characters: "b")
            }
        }
        #expect(messages.isEmpty)
    }

    @Test
    func strictReportsOtherCallsToTheVerifiedMocksInBetween() {
        database.noReturn()
        cache.noReturn()
        _ = database.count(characters: "b")

        let messages = collectingMessages {
            inOrder(strict: true) {
                verify(database).noReturn()
                verify(database).count(characters: "b")
            }
        }
        // The cache isn't verified in the block, so its call doesn't count.
        #expect(messages.isEmpty)

        let strictMessages = collectingMessages {
            inOrder(strict: true) {
                verify(database).noReturn()
                verify(cache).count(characters: any())
                verify(database).count(characters: "b")
            }
        }
        #expect(strictMessages.count == 2)
        #expect(strictMessages.last == "Wanted the verified calls in strict order, but these calls came in between:\n  noReturn()")
    }

    @Test
    func verifiesTheSameMemberAgainLaterInTheOrder() {
        database.noReturn()
        cache.noReturn()
        database.noReturn()

        let messages = collectingMessages {
            inOrder {
                verify(database).noReturn()
                verify(cache).noReturn()
                verify(database).noReturn()
            }
        }
        #expect(messages.isEmpty)
    }

    @Test
    func timesTakesThatManyCallsFromTheCursor() {
        database.noReturn()
        database.noReturn()
        cache.noReturn()

        let messages = collectingMessages {
            inOrder {
                verify(database, times(2)).noReturn()
                verify(cache).noReturn()
            }
        }
        #expect(messages.isEmpty)
    }

    @Test
    func neverLooksAtEveryCallAfterThePreviousVerification() {
        database.noReturn()
        cache.noReturn()

        let passing = collectingMessages {
            inOrder {
                verify(cache).noReturn()
                verify(database, never()).noReturn()
            }
        }
        #expect(passing.isEmpty)

        let failing = collectingMessages {
            inOrder {
                verify(database).noReturn()
                verify(cache, never()).noReturn()
            }
        }
        #expect(failing.count == 1)
    }

    @Test
    func countsAsVerificationForVerifyNoMoreInteractions() {
        database.noReturn()
        database.noReturn()

        let messages = collectingMessages {
            inOrder {
                verify(database).noReturn()
            }
            verifyNoMoreInteractions(database)
        }
        #expect(messages == ["No more interactions wanted but some found:\n1. noReturn()"])
    }

    /// The failures `body` reports, without failing the test.
    private func collectingMessages(_ body: () -> Void) -> [String] {
        let messages = Locked<[String]>([])
        var configuration = CuckooConfiguration.current
        configuration.failureHandler = { message, _ in
            messages.withLock { $0.append(message) }
        }
        CuckooConfiguration.$current.withValue(configuration) {
            body()
        }
        return messages.withLock { $0 }
    }
}
