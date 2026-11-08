import Foundation
import Testing
@testable import CuckooMocks
@testable import CuckooTestSources

// `Cuckoofile.toml` excludes `ExcludedTestClass`, so no mock is generated for it, while `IncludedTestClass` gets one.
struct ExcludedStubTest {
    @Test
    func classAvailability() {
        _ = ExcludedTestClass()

        #expect(NSClassFromString("CuckooTestSources.ExcludedTestClass") != nil)
        #expect(NSClassFromString("CuckooMocks.MockExcludedTestClass") == nil)
        _ = IncludedTestClass()
        _ = MockIncludedTestClass()
    }

    @Test
    func protocolAvailability() {
        _ = MockIncludedProtocol()

        #expect(NSClassFromString("CuckooMocks.MockExcludedProtocol") == nil)
    }
}
