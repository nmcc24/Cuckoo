import Testing
import Cuckoo
@testable import CuckooMocks
@testable import CuckooTestSources

struct OverloadAndAliasShapesTests {
    /// `Self.ID` is the mock's copy of the typealias, and `Self.Callback` a closure the mock records.
    @Test
    func aTypealiasNamedThroughSelfIsStubbedAndVerified() {
        let mock = MockAliasedLookup()
        stub(mock) { stub in
            when(stub.find(1)).thenReturn(2)
            when(stub.each(any())).then { callback in callback(3) }
        }

        var seen: [Int] = []
        mock.each { seen.append($0) }
        #expect(mock.find(1) == 2)
        #expect(seen == [3])
        verify(mock).find(1)
        verify(mock).each(any())
    }

    /// A typealias isn't `Self`: the member forwards to a default implementation.
    @Test
    func aMemberNamingATypealiasThroughSelfForwardsToTheDefaultImplementation() {
        let mock = MockAliasedLookup()
        mock.enableDefaultImplementation(AliasedLookupImplementation())

        var seen: [Int] = []
        mock.each { seen.append($0) }
        #expect(mock.find(1) == 2)
        #expect(seen == [7])
    }
}
