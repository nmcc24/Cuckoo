import Testing
import XCTest
@testable import Cuckoo
@testable import CuckooMocks
@testable import CuckooTestSources

final class FailTest: XCTestCase {
    func testMissingInvocation() {
        let error = TestUtils.catchCuckooFail {
            let mock = MockTestedClass()

            verify(mock).noReturn()
        }

        XCTAssertEqual(error, "Wanted 1 times but not invoked.\nThe mock received no calls.")
    }

    func testNoInvocation2Wanted() {
        let error = TestUtils.catchCuckooFail {
            let mock = MockTestedClass()
            stub(mock) { mock in
                when(mock.noReturn()).thenDoNothing()
            }

            mock.noReturn()

            verify(mock, times(2)).noReturn()
        }

        XCTAssertEqual(error, "Wanted 2 times but invoked 1 times.\nCalls to noReturn():\n  1. noReturn() matches")
    }

    func testInvocationNeverWanted() {
        let error = TestUtils.catchCuckooFail {
            let mock = MockTestedClass()
            stub(mock) { mock in
                when(mock.noReturn()).thenDoNothing()
            }

            mock.noReturn()

            verify(mock, never()).noReturn()
        }

        XCTAssertEqual(error, "Wanted never but invoked 1 times.\nCalls to noReturn():\n  1. noReturn() matches")
    }

    func testInvocationAtLeast2Wanted() {
        let error = TestUtils.catchCuckooFail {
            let mock = MockTestedClass()
            stub(mock) { mock in
                when(mock.noReturn()).thenDoNothing()
            }

            mock.noReturn()

            verify(mock, atLeast(2)).noReturn()
        }

        XCTAssertEqual(error, "Wanted at least 2 times but invoked 1 times.\nCalls to noReturn():\n  1. noReturn() matches")
    }

    func test2InvocationAtMost1Wanted() {
        let error = TestUtils.catchCuckooFail {
            let mock = MockTestedClass()
            stub(mock) { mock in
                when(mock.noReturn()).thenDoNothing()
            }

            mock.noReturn()
            mock.noReturn()

            verify(mock, atMost(1)).noReturn()
        }
        
        XCTAssertEqual(error, "Wanted at most 1 times but invoked 2 times.\nCalls to noReturn():\n  1. noReturn() matches\n  2. noReturn() matches")
    }

    func testCallMatcherOr() {
        let error = TestUtils.catchCuckooFail {
            let mock = MockTestedClass()
            stub(mock) { mock in
                when(mock.noReturn()).thenDoNothing()
            }

            verify(mock, times(1).or(times(2))).noReturn()
        }

        XCTAssertEqual(error, "Wanted either 1 times or 2 times but not invoked.\nThe mock received no calls.")
    }

    func testCallMatcherAnd() {
        let error = TestUtils.catchCuckooFail {
            let mock = MockTestedClass()
            stub(mock) { mock in
                when(mock.noReturn()).thenDoNothing()
            }
            
            verify(mock, atLeast(1).and(atMost(2))).noReturn()
        }

        XCTAssertEqual(error, "Wanted both at least 1 times and at most 2 times but not invoked.\nThe mock received no calls.")
    }

    func testVerifyNoMoreInteractionsFail() {
        let error = TestUtils.catchCuckooFail {
            let mock = MockTestedClass().withEnabledSuperclassSpy()

            mock.withOptionalClosure("a", closure: nil)
            mock.noReturn()
            _ = mock.count(characters: "b")
            let _ = mock.readWriteProperty
            mock.readWriteProperty = 1
            mock.withOptionalClosure("c", closure: { _ in })

            verifyNoMoreInteractions(mock)
        }

        XCTAssertEqual(error, ["No more interactions wanted but some found:",
                               "1. withOptionalClosure(\"a\", nil)",
                               "2. noReturn()",
                               "3. count(\"b\")",
                               "4. readWriteProperty#get",
                               "5. readWriteProperty#set(1)",
                               "6. withOptionalClosure(\"c\", Optional((Function)))"].joined(separator: "\n"))
    }
}

struct FailSwiftTestingTests {
    @Test
    func missingInvocation() {
        withKnownIssue {
            let mock = MockTestedClass()

            verify(mock).noReturn()
        } matching: { issue in
            issue.comments.map(\.rawValue) == [
                "Wanted 1 times but not invoked.\nThe mock received no calls."
            ]
        }
    }

    @Test
    func noInvocation2Wanted() {
        withKnownIssue {
            let mock = MockTestedClass()
            stub(mock) { mock in
                when(mock.noReturn()).thenDoNothing()
            }

            mock.noReturn()

            verify(mock, times(2)).noReturn()
        } matching: { issue in
            issue.comments.map(\.rawValue) == [
                "Wanted 2 times but invoked 1 times.\nCalls to noReturn():\n  1. noReturn() matches"
            ]
        }
    }

    @Test
    func invocationNeverWanted() {
        withKnownIssue {
            let mock = MockTestedClass()
            stub(mock) { mock in
                when(mock.noReturn()).thenDoNothing()
            }

            mock.noReturn()

            verify(mock, never()).noReturn()
        } matching: { issue in
            issue.comments.map(\.rawValue) == [
                "Wanted never but invoked 1 times.\nCalls to noReturn():\n  1. noReturn() matches"
            ]
        }
    }

    @Test
    func invocationAtLeast2Wanted() {
        withKnownIssue {
            let mock = MockTestedClass()
            stub(mock) { mock in
                when(mock.noReturn()).thenDoNothing()
            }

            mock.noReturn()

            verify(mock, atLeast(2)).noReturn()
        } matching: { issue in
            issue.comments.map(\.rawValue) == [
                "Wanted at least 2 times but invoked 1 times.\nCalls to noReturn():\n  1. noReturn() matches"
            ]
        }
    }

    @Test
    func invocationAtMost1Wanted() {
        withKnownIssue {
            let mock = MockTestedClass()
            stub(mock) { mock in
                when(mock.noReturn()).thenDoNothing()
            }

            mock.noReturn()
            mock.noReturn()

            verify(mock, atMost(1)).noReturn()
        } matching: { issue in
            issue.comments.map(\.rawValue) == [
                "Wanted at most 1 times but invoked 2 times.\nCalls to noReturn():\n  1. noReturn() matches\n  2. noReturn() matches"
            ]
        }
    }

    @Test
    func callMatcherOr() {
        withKnownIssue {
            let mock = MockTestedClass()
            stub(mock) { mock in
                when(mock.noReturn()).thenDoNothing()
            }

            verify(mock, times(1).or(times(2))).noReturn()
        } matching: { issue in
            issue.comments.map(\.rawValue) == [
                "Wanted either 1 times or 2 times but not invoked.\nThe mock received no calls."
            ]
        }
    }

    @Test
    func callMatcherAnd() {
        withKnownIssue {
            let mock = MockTestedClass()
            stub(mock) { mock in
                when(mock.noReturn()).thenDoNothing()
            }
            
            verify(mock, atLeast(1).and(atMost(2))).noReturn()
        } matching: { issue in
            issue.comments.map(\.rawValue) == [
                "Wanted both at least 1 times and at most 2 times but not invoked.\nThe mock received no calls."
            ]
        }
    }

    @Test
    func verifyNoMoreInteractionsFail() {
        withKnownIssue {
            let mock = MockTestedClass().withEnabledSuperclassSpy()

            mock.withOptionalClosure("a", closure: nil)
            mock.noReturn()
            _ = mock.count(characters: "b")
            let _ = mock.readWriteProperty
            mock.readWriteProperty = 1
            mock.withOptionalClosure("c", closure: { _ in })

            verifyNoMoreInteractions(mock)
        } matching: { issue in
            issue.comments.map(\.rawValue) == [
                ["No more interactions wanted but some found:",
               "1. withOptionalClosure(\"a\", nil)",
               "2. noReturn()",
               "3. count(\"b\")",
               "4. readWriteProperty#get",
               "5. readWriteProperty#set(1)",
               "6. withOptionalClosure(\"c\", Optional((Function)))"
                ].joined(separator: "\n")
            ]
        }
    }
}
