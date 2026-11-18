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

    /// The type eraser's setters take function values spelled through a typealias, and an implicitly unwrapped one.
    @Test
    func theTypeEraserSetsFunctionAndImplicitlyUnwrappedValues() {
        let implementation = ObservedStoreImplementation()
        let mock = MockObservedStore<String>()
        mock.enableDefaultImplementation(implementation)

        mock.handler = { $0 * 2 }
        #expect(implementation.handler(2) == 4)
        #expect(mock.handler(3) == 6)

        mock[0] = { $0 + 1 }
        #expect(implementation.handler(2) == 3)
        #expect(mock[0](3) == 4)

        #expect(mock.implicit == nil)
        mock.implicit = "set"
        #expect(implementation.implicit == "set")
        #expect(mock.implicit == "set")
    }
}
