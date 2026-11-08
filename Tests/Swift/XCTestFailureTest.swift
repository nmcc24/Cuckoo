#if canImport(ObjectiveC)
import XCTest
import Cuckoo
@testable import CuckooMocks
@testable import CuckooTestSources

/// A failure outside a Swift Testing test goes to XCTest, through `XCTFail`. Only Apple's XCTest can expect a
/// failure, so this route is checked on Apple platforms; `FailTest` covers the messages everywhere.
final class XCTestFailureTest: XCTestCase {
    func testFailedVerificationFailsTheTest() {
        let options = XCTExpectedFailure.Options()
        options.issueMatcher = { issue in
            issue.compactDescription.contains("Wanted 1 times but not invoked.")
        }

        XCTExpectFailure("verify reports through XCTFail", options: options) {
            let mock = MockTestedClass()

            verify(mock).noReturn()
        }
    }
}
#endif
