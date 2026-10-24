import XCTest
import Cuckoo
import CuckooMocks // not @testable
import CuckooTestSources // not @testable

final class OpenClassTest: XCTestCase {
    func testOpenClass() throws {
        XCTAssertNotNil(MockOpenClass())
    }
}
