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

    var handler: @Sendable (ReportedFailure) -> Void {
        { failure in self.messages.withLock { $0.append(failure.message) } }
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
        let log = FailureLog()
        let mock = MockTestedProtocol()

        withTraitConfiguration(failureHandler: log.handler) {
            #expect(mock.count(characters: "a") == 42)
            #expect(mock.readOnlyProperty == "forty-two")
            // The registry still answers types the trait doesn't cover.
            #expect(mock.optionalProperty == nil)
        }
        #expect(log.all.count == 3)
        #expect(log.all.allSatisfy { $0.hasPrefix("No stub for method") })
    }

    @Test(.cuckoo(defaultValues: DefaultValues()))
    func testTraitOverridesTheSuite() {
        let log = FailureLog()
        let mock = MockTestedProtocol()

        withTraitConfiguration(failureHandler: log.handler) {
            #expect(mock.count(characters: "a") == 0)
        }
        #expect(log.all.count == 1)
    }

    /// Runs `body` with the configuration the traits set, plus `failureHandler`, so the unstubbed calls these tests
    /// make on purpose don't fail them.
    private func withTraitConfiguration(failureHandler: @escaping @Sendable (ReportedFailure) -> Void, _ body: () -> Void) {
        var configuration = CuckooConfiguration.current
        configuration.failureHandler = failureHandler
        CuckooConfiguration.$current.withValue(configuration, operation: body)
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
    /// Testing. The mock remembers the Swift Testing test it was created in, and the failure goes to Swift Testing
    /// at that test, which Swift Testing attributes it to.
    @Test
    func failureFromADetachedTaskGoesToSwiftTestingAtTheCreatingTest() async throws {
        let mock = MockTestedProtocol()
        let creatingTest = mock.cuckooManager.creatingTest

        let location = await Task.detached {
            swiftTestingIssueLocation(for: nil, creatingTest: creatingTest)
        }.value

        let testLocation = try #require(Test.current?.sourceLocation)
        #expect(location == testLocation)
    }

    @Test
    func failureWithALocationKeepsIt() async throws {
        let mock = MockTestedProtocol()
        let creatingTest = mock.cuckooManager.creatingTest

        let location = await Task.detached {
            swiftTestingIssueLocation(for: ("Module/File.swift", "/path/File.swift", 12, 3), creatingTest: creatingTest)
        }.value

        #expect(location?.fileID == "Module/File.swift")
        #expect(location?.line == 12)
    }

    /// Each way a mock fails passes on the test that created it, which a failure from a task outside the test
    /// needs to reach Swift Testing.
    @Test
    func everyFailurePathPassesTheCreatingTest() async throws {
        let testLocation = try #require(Test.current?.sourceLocation)
        let mock = MockTestedProtocol()
        stub(mock) { stub in
            when(stub.noReturn()).thenDoNothing()
        }
        let unfinished = MockTestedProtocol()
        stub(unfinished) { stub in
            _ = when(stub.count(characters: "a"))
        }
        mock.noReturn()
        mock.noReturn()

        let failures = Locked<[ReportedFailure]>([])
        var configuration = CuckooConfiguration.current
        configuration.failureHandler = { failure in failures.withLock { $0.append(failure) } }
        await CuckooConfiguration.$current.withValue(configuration) {
            _ = mock.count(characters: "unstubbed")
            _ = unfinished.count(characters: "a")
            verify(mock, times(3)).noReturn()
            verifyNoMoreInteractions(mock)
            inOrder {
                verify(mock).count(characters: "unstubbed")
                verify(mock, times(2)).noReturn()
            }
            inOrder(strict: true) {
                verify(mock, times(2)).noReturn()
                verify(unfinished).count(characters: "a")
            }
            await eventually(timeout: .milliseconds(20)) {
                verify(mock, never()).noReturn()
            }
        }

        let reported = failures.withLock { $0 }
        #expect(reported.count == 7, "\(reported.map(\.message))")
        for failure in reported {
            #expect(failure.creatingTest?.sourceLocation == testLocation, "\(failure.message)")
        }
    }

    @Test
    func failureOfAMockCreatedOutsideATestGoesToXCTest() async {
        let location = await Task.detached {
            let creatingTest = MockTestedProtocol().cuckooManager.creatingTest
            return swiftTestingIssueLocation(for: nil, creatingTest: creatingTest)
        }.value

        #expect(location == nil)
    }
}
