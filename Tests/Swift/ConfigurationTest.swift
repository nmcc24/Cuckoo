import Testing
@testable import Cuckoo
@testable import CuckooMocks
@testable import CuckooTestSources

/// Collects the failures reported in its scope, so a test can check them without failing.
private final class FailureLog: Sendable {
    private let messages = Locked<[String]>([])

    var all: [String] {
        messages.withLock { $0 }
    }

    var handler: CuckooConfiguration.FailureHandler {
        { message, _ in self.messages.withLock { $0.append(message) } }
    }
}

struct UnstubbedCallTests {
    @Test
    func recordsAnIssueAndReturnsTheDefaultValue() {
        let mock = MockTestedProtocol()

        withKnownIssue {
            #expect(mock.count(characters: "a") == 0)
        } matching: { issue in
            issue.comments.map(\.rawValue).first?.hasPrefix("No stub for method `count(characters") == true
        }
    }

    @Test
    func returnsEmptyValuesForOptionalsAndCollections() {
        let log = FailureLog()
        let mock = MockTestedProtocol()

        CuckooConfiguration.$current.withValue(CuckooConfiguration(failureHandler: log.handler)) {
            #expect(mock.optionalProperty == nil)
            #expect(mock.genericReturn().isEmpty)
            #expect(mock.readOnlyProperty == "")
        }
        #expect(log.all.count == 3)
    }

    @Test
    func throwingMembersThrowUnstubbedCall() {
        let log = FailureLog()
        let mock = MockTestedProtocol()

        CuckooConfiguration.$current.withValue(CuckooConfiguration(failureHandler: log.handler)) {
            #expect(throws: CuckooError.unstubbedCall(method: "withThrows() throws -> Int")) {
                try mock.withThrows()
            }
        }
        #expect(log.all.count == 1)
    }

    @Test
    func anUnfinishedStubIsReportedNotCrashed() {
        let log = FailureLog()
        let mock = MockTestedProtocol()
        stub(mock) { stub in
            _ = when(stub.count(characters: "a"))
        }

        CuckooConfiguration.$current.withValue(CuckooConfiguration(failureHandler: log.handler)) {
            #expect(mock.count(characters: "a") == 0)
        }
        #expect(log.all.first?.contains("wasn't finished (missing thenReturn())") == true)
    }

    @Test
    func stubsWinOverDefaults() {
        let log = FailureLog()
        let mock = MockTestedProtocol()
        stub(mock) { stub in
            when(stub.count(characters: "a")).thenReturn(7)
        }

        CuckooConfiguration.$current.withValue(CuckooConfiguration(failureHandler: log.handler)) {
            #expect(mock.count(characters: "a") == 7)
            #expect(log.all.isEmpty)
            #expect(mock.count(characters: "b") == 0)
            #expect(log.all.count == 1)
        }
    }
}

private let fortyTwo: DefaultValues = {
    var values = DefaultValues()
    values.register(42)
    values.register("forty-two")
    return values
}()

@Suite(.cuckoo(defaultValues: fortyTwo))
struct CuckooTraitTests {
    @Test
    func suiteDefaultValuesApplyToItsTests() {
        let mock = MockTestedProtocol()

        withKnownIssue {
            #expect(mock.count(characters: "a") == 42)
            #expect(mock.readOnlyProperty == "forty-two")
            // The registry still answers types the trait doesn't cover.
            #expect(mock.optionalProperty == nil)
        } matching: { issue in
            issue.comments.map(\.rawValue).first?.hasPrefix("No stub for method") == true
        }
    }

    @Test(.cuckoo(defaultValues: DefaultValues()))
    func testTraitOverridesTheSuite() {
        let mock = MockTestedProtocol()

        withKnownIssue {
            #expect(mock.count(characters: "a") == 0)
        } matching: { issue in
            issue.comments.map(\.rawValue).first?.hasPrefix("No stub for method") == true
        }
    }

    @Test
    func failureHandlerTakesFailuresInsteadOfTheFramework() {
        let log = FailureLog()
        let mock = MockTestedProtocol()

        CuckooConfiguration.$current.withValue(CuckooConfiguration(failureHandler: log.handler)) {
            _ = mock.count(characters: "a")
            verify(mock, times(2)).count(characters: "a")
        }
        #expect(log.all.count == 2)
        #expect(log.all.last == "Wanted 2 times but invoked 1 times.\nCalls to count(characters:):\n  1. count(\"a\") matches")
    }
}
