import Testing
@testable import Cuckoo
@testable import CuckooMocks
@testable import CuckooTestSources

struct StubFunctionTest {
    @Test
    func then() {
        let mock = MockTestedClass()
        stub(mock) { mock in
            when(mock.count(characters: "a")).then {
                return $0.count * 2
            }
        }

        #expect(mock.count(characters: "a") == 2)
    }

    @Test
    func thenReturn() {
        let mock = MockTestedClass()
        stub(mock) { mock in
            when(mock.count(characters: "a")).thenReturn(2)
        }

        #expect(mock.count(characters: "a") == 2)
    }

    @Test
    func thenCallRealImplementation() {
        let mock = MockTestedClass().withEnabledSuperclassSpy()
        stub(mock) { mock in
            when(mock.count(characters: "a")).thenCallRealImplementation()
        }

        #expect(mock.count(characters: "a") == 1)
    }
}
