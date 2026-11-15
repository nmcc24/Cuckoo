import Testing
import Cuckoo
@testable import CuckooMocks
@testable import CuckooTestSources

/// A generic subscript of a protocol with an associated type reaches the default implementation.
struct TypeErasureShapesTest {
    @Test
    func genericSubscriptForwardsToTheDefaultImplementation() {
        let mock = MockKeyedStore<String>()
        mock.enableDefaultImplementation(StringKeyedStore())

        #expect(mock[7] == "value for 7")
        verify(mock)[equal(to: 7)].get()
    }
}
