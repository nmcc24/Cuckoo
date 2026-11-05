import XCTest
@testable import CuckooMocks
@testable import CuckooTestSources

// `Cuckoofile.toml` excludes `ExcludedTestClass`, so no mock is generated for it, while `IncludedTestClass` gets one.
final class ExcludedStubTest: XCTestCase {
    func testClassAvailability() {
        XCTAssertNotNil(ExcludedTestClass())

        XCTAssertNotNil(NSClassFromString("CuckooTestSources.ExcludedTestClass"))
        XCTAssertNil(NSClassFromString("CuckooMocks.MockExcludedTestClass"))
        XCTAssertNotNil(IncludedTestClass())
        XCTAssertNotNil(MockIncludedTestClass())
    }

    func testProtocolAvailability() {
        XCTAssertNotNil(MockIncludedProtocol())

        XCTAssertNil(NSClassFromString("CuckooMocks.MockExcludedProtocol"))
    }
}
