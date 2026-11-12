import Testing
@testable import Cuckoo
@testable import CuckooMocks
@testable import CuckooTestSources

/// The failures `verify` and `verifyNoMoreInteractions` report. Each scenario runs twice: through a configuration's
/// failure handler, and as the Swift Testing issue a test without one records.
struct FailTest {
    struct Scenario: Sendable, CustomTestStringConvertible {
        let testDescription: String
        let run: @Sendable () -> Void
        let message: String
    }

    static let scenarios: [Scenario] = [
        Scenario(testDescription: "missing invocation", run: {
            let mock = MockTestedClass()
            verify(mock).noReturn()
        }, message: "Wanted 1 time but not invoked.\nThe mock received no calls."),
        Scenario(testDescription: "2 wanted, 1 made", run: {
            let mock = stubbedMock()
            mock.noReturn()
            verify(mock, times(2)).noReturn()
        }, message: "Wanted 2 times but invoked 1 time.\nCalls to noReturn():\n  1. noReturn() matches"),
        Scenario(testDescription: "never wanted", run: {
            let mock = stubbedMock()
            mock.noReturn()
            verify(mock, never()).noReturn()
        }, message: "Wanted never but invoked 1 time.\nCalls to noReturn():\n  1. noReturn() matches"),
        Scenario(testDescription: "at least 2 wanted", run: {
            let mock = stubbedMock()
            mock.noReturn()
            verify(mock, atLeast(2)).noReturn()
        }, message: "Wanted at least 2 times but invoked 1 time.\nCalls to noReturn():\n  1. noReturn() matches"),
        Scenario(testDescription: "at most 1 wanted", run: {
            let mock = stubbedMock()
            mock.noReturn()
            mock.noReturn()
            verify(mock, atMost(1)).noReturn()
        }, message: "Wanted at most 1 time but invoked 2 times.\nCalls to noReturn():\n  1. noReturn() matches\n  2. noReturn() matches"),
        Scenario(testDescription: "call matcher or", run: {
            verify(stubbedMock(), times(1).or(times(2))).noReturn()
        }, message: "Wanted either 1 time or 2 times but not invoked.\nThe mock received no calls."),
        Scenario(testDescription: "call matcher and", run: {
            verify(stubbedMock(), atLeast(1).and(atMost(2))).noReturn()
        }, message: "Wanted both at least 1 time and at most 2 times but not invoked.\nThe mock received no calls."),
        Scenario(testDescription: "verifyNoMoreInteractions", run: {
            let mock = MockTestedClass().withEnabledSuperclassSpy()
            mock.withOptionalClosure("a", closure: nil)
            mock.noReturn()
            _ = mock.count(characters: "b")
            _ = mock.readWriteProperty
            mock.readWriteProperty = 1
            mock.withOptionalClosure("c", closure: { _ in })
            verifyNoMoreInteractions(mock)
        }, message: """
            No more interactions wanted but some found:
            1. withOptionalClosure("a", nil)
            2. noReturn()
            3. count("b")
            4. readWriteProperty#get
            5. readWriteProperty#set(1)
            6. withOptionalClosure("c", Optional((Function)))
            """),
    ]

    private static func stubbedMock() -> MockTestedClass {
        let mock = MockTestedClass()
        stub(mock) { mock in
            when(mock.noReturn()).thenDoNothing()
        }
        return mock
    }

    @Test(arguments: scenarios)
    func reachesTheFailureHandler(_ scenario: Scenario) {
        #expect(TestUtils.catchCuckooFail(inClosure: scenario.run) == scenario.message)
    }

    @Test(arguments: scenarios)
    func isASwiftTestingIssue(_ scenario: Scenario) {
        withKnownIssue {
            scenario.run()
        } matching: { issue in
            issue.comments.map(\.rawValue) == [scenario.message]
        }
    }
}
