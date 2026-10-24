import XCTest
@testable import CuckooMocks
@testable import CuckooTestSources

final class NSObjectProtocolTest: XCTestCase {

    private var mockProtocolNotInheritingFromNSObjectProtocol: MockProtocolNotInheritingFromNSObjectProtocol!

    override func setUp() {
        super.setUp()

        mockProtocolNotInheritingFromNSObjectProtocol = MockProtocolNotInheritingFromNSObjectProtocol()
    }

    func testProtocolNotInheritingFromNSObjectProtocol() {
        XCTAssert(!(mockProtocolNotInheritingFromNSObjectProtocol is NSObject))
    }
}
