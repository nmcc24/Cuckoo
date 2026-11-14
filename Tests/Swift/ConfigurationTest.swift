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
            // The call happens inside the mock, so the issue points at the test rather than into Cuckoo.
            issue.comments.map(\.rawValue).first?.hasPrefix("No stub for method `count(characters") == true
                && issue.sourceLocation?.fileName == "ConfigurationTest.swift"
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
    func factoriesGiveTuplesAndNonSendableClassesADefault() {
        let log = FailureLog()
        let mock = MockDefaultValueSource()
        var configuration = CuckooConfiguration(failureHandler: log.handler)
        configuration.defaultValues.register(for: (Int, String).self) { (7, "seven") }
        configuration.defaultValues.register(for: Canvas.self) { Canvas() }

        CuckooConfiguration.$current.withValue(configuration) {
            #expect(mock.pair() == (7, "seven"))
            let first = mock.canvas()
            first.strokes.append("line")
            // Each call gets a new value, so one test's changes don't leak into the next call.
            #expect(mock.canvas().strokes.isEmpty)
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
        #expect(log.all.last == "Wanted 2 times but invoked 1 time.\nCalls to count(characters:):\n  1. count(\"a\") matches")
    }
}

struct FailuresOutsideTheTestTaskTests {
    /// A detached task has no current test, so a failure there would go to XCTest, which ignores it under Swift
    /// Testing. The mock remembers that it was created in a Swift Testing test, and reports to Swift Testing.
    @Test
    func mockRemembersItWasCreatedInASwiftTestingTest() async {
        let mock = MockTestedProtocol()
        #expect(mock.cuckoo_manager.createdInSwiftTesting)

        let detachedHasNoTest = await Task.detached { !isRunningSwiftTestingTest() }.value
        #expect(detachedHasNoTest)
    }

    @Test
    func mockCreatedOutsideATestDoesNotClaimSwiftTesting() async {
        let createdInSwiftTesting = await Task.detached { MockTestedProtocol().cuckoo_manager.createdInSwiftTesting }.value
        #expect(!createdInSwiftTesting)
    }
}
