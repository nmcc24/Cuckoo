import Testing
@testable import Cuckoo
@testable import CuckooMocks
@testable import CuckooTestSources

struct StubNoReturnThrowingFunctionTest {
    @Test
    func then() {
        let mock = MockTestedClass()
        var called = false
        stub(mock) { mock in
            when(mock.withNoReturnThrows()).then {
                called = true
            }
        }

        try! mock.withNoReturnThrows()

        #expect(called)
    }

    @Test
    func thenCallRealImplementation() {
        let mock = MockTestedClass().withEnabledSuperclassSpy()
        stub(mock) { mock in
            when(mock.withNoReturnThrows()).thenCallRealImplementation()
        }

        try! mock.withNoReturnThrows()
    }

    @Test
    func thenDoNothing() {
        let mock = MockTestedClass()
        stub(mock) { mock in
            when(mock.withNoReturnThrows()).thenDoNothing()
        }

        try! mock.withNoReturnThrows()
    }

    @Test
    func thenThrow() {
        let mock = MockTestedClass()
        stub(mock) { mock in
            when(mock.withNoReturnThrows()).thenThrow(TestError.unknown)
        }

        var catched = false
        do {
            try mock.withNoReturnThrows()
        } catch {
            catched = true
        }

        #expect(catched)
    }

    private enum TestError: Error {
        case unknown
    }
}
