import Testing
@testable import Cuckoo
@testable import CuckooMocks
@testable import CuckooTestSources

struct StubNoReturnFunctionTest {
    @Test
    func then() {
        let mock = MockTestedClass()
        var called = false
        stub(mock) { mock in
            when(mock.noReturn()).then {
                called = true
            }
        }

        mock.noReturn()

        #expect(called)
    }

    @Test
    func thenCallRealImplementation() {
        let mock = MockTestedClass().withEnabledSuperclassSpy()
        stub(mock) { mock in
            when(mock.noReturn()).thenCallRealImplementation()
        }

        mock.noReturn()
    }

    @Test
    func thenDoNothing() {
        let mock = MockTestedClass()
        stub(mock) { mock in
            when(mock.noReturn()).thenDoNothing()
        }

        mock.noReturn()
    }
}
