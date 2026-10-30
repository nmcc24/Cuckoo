import Testing
import Cuckoo
@testable import CuckooMocks
@testable import CuckooTestSources

/// The mocks file imports every source type by name, so a type that shares its name with one of an import of the
/// mocks (Foundation's `Unit`), or with its own module, still means the source type there.
struct ImportClashTests {
    @Test
    func sourceTypesWinOverSameNamedImports() {
        let mock = MockUnitConverter()
        let meters = Unit(symbol: "m")
        stub(mock) { stub in
            when(stub.convert(any(), to: equal(to: meters))).then { value, _ in value * 2 }
            when(stub.describe(equal(to: CuckooTestSources(id: 1)))).thenReturn("one")
        }

        #expect(mock.convert(3, to: meters) == 6)
        #expect(mock.describe(CuckooTestSources(id: 1)) == "one")
        verify(mock).convert(equal(to: 3), to: equal(to: meters))
        verify(mock).describe(any())
    }
}
