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
            issue.compactDescription.contains("Wanted 1 time but not invoked.")
        }

        XCTExpectFailure("verify reports through XCTFail", options: options) {
            let mock = MockTestedClass()

            verify(mock).noReturn()
        }
    }

    /// The failure points at the `verify` line, with the full path Xcode needs to show it there: a module-relative
    /// `#fileID`-style path, which `#file` gives in a Swift 6 module, leaves it unplaced.
    func testFailureIsReportedAtTheVerifyLine() {
        let expectedFile = URL(filePath: "\(#filePath)")
        let expectedLine = #line + 9
        let options = XCTExpectedFailure.Options()
        options.issueMatcher = { issue in
            issue.sourceCodeContext.location?.fileURL == expectedFile
                && issue.sourceCodeContext.location?.lineNumber == expectedLine
        }

        XCTExpectFailure("verify reports at its own line", options: options) {
            let mock = MockTestedClass()
            verify(mock).noReturn()
        }
    }
}
#endif
