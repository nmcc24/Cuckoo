import Testing
import Cuckoo
import CuckooMocks // not @testable
import CuckooTestSources // not @testable

struct OpenClassTest {
    @Test
    func openClass() throws {
        _ = MockOpenClass()
    }
}
