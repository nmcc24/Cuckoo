#if canImport(ObjectiveC)
// Inheriting `NSObjectProtocol` only changes a mock where Objective-C interop exists.
import Foundation
import Testing
@testable import CuckooMocks
@testable import CuckooTestSources

struct NSObjectProtocolTest {

    private let mockProtocolNotInheritingFromNSObjectProtocol = MockProtocolNotInheritingFromNSObjectProtocol()

    @Test
    func protocolNotInheritingFromNSObjectProtocol() {
        #expect(!(mockProtocolNotInheritingFromNSObjectProtocol is NSObject))
    }
}
#endif
