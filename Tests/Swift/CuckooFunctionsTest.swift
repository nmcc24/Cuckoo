import Testing
@testable import Cuckoo
@testable import CuckooMocks
@testable import CuckooTestSources

struct CuckooFunctionsTest {
    @Test
    func testReset() {
        let mock = MockTestedClass().withEnabledSuperclassSpy()
        stub(mock) { mock in
            when(mock.count(characters: anyString())).thenReturn(10)
        }
        #expect(mock.count(characters: "a") == 10)
        
        reset(mock)
        
        verify(mock, never()).count(characters: "a")
        #expect(mock.count(characters: "a") == 1)
        verify(mock).count(characters: "a")
    }

    @Test
    func testClearStubs() {
        let mock = MockTestedClass().withEnabledSuperclassSpy()
        stub(mock) { mock in
            when(mock.count(characters: anyString())).thenReturn(10)
        }
        #expect(mock.count(characters: "a") == 10)

        clearStubs(mock)

        verify(mock).count(characters: "a")
        #expect(mock.count(characters: "a") == 1)
        verify(mock, times(2)).count(characters: "a")
    }

    @Test
    func testClearInvocations() {
        let mock = MockTestedClass()
        stub(mock) { mock in
            when(mock.count(characters: anyString())).thenReturn(10)
        }
        #expect(mock.count(characters: "a") == 10)

        clearInvocations(mock)

        verify(mock, never()).count(characters: "a")
        #expect(mock.count(characters: "a") == 10)
        verify(mock).count(characters: "a")
    }

    @Test
    func testVerifyNoMoreInteractions() {
        let mock = MockTestedClass()
        stub(mock) { mock in
            when(mock.noReturn()).thenDoNothing()
        }

        mock.noReturn()
        verify(mock).noReturn()

        verifyNoMoreInteractions(mock)
    }
}
