import Testing
import Cuckoo
@testable import CuckooMocks
@testable import CuckooTestSources

struct VerificationTest {
    @Test
    func testVerify() {
        let mock = MockTestedClass()
        stub(mock) { mock in
            when(mock.noReturn()).thenDoNothing()
        }
        
        mock.noReturn()
        
        verify(mock).noReturn()
    }

    @Test
    func verifyWithCallMatcher() {
        let mock = MockTestedClass()
        stub(mock) { mock in
            when(mock.noReturn()).thenDoNothing()
        }
        
        mock.noReturn()
        mock.noReturn()
        
        verify(mock, times(2)).noReturn()
    }

    @Test
    func verifyWithMultipleDifferentCalls() {
        let mock = MockTestedClass()
        stub(mock) { mock in
            when(mock.noReturn()).thenDoNothing()
            when(mock.count(characters: any())).thenReturn(1)
        }

        _ = mock.count(characters: "a")
        mock.noReturn()

        verify(mock).noReturn()
        verify(mock).count(characters: any())
    }

    @Test
    func verifyWithGenericReturn() {
        let mock = MockGenericMethodClass<String>()
        stub(mock) { mock in
            when(mock.genericReturn(any())).thenReturn("")
        }

        let _: String? = mock.genericReturn("Foo")

        verify(mock).genericReturn(equal(to: "Foo")).with(returnType: String?.self)
    }

    /// A generic member's calls with another return type are other calls: they aren't counted, and stay unverified.
    @Test
    func verifyCountsOnlyTheCallsWithItsReturnType() {
        let mock = MockGenericMethodClass<String>()
        stub(mock) { mock in
            when(mock.genericReturn(any())).thenReturn("")
            when(mock.genericReturn(any())).thenReturn(1)
        }

        let _: String? = mock.genericReturn("Foo")
        let _: String? = mock.genericReturn("Foo")
        let _: Int? = mock.genericReturn("Foo")

        verify(mock, times(2)).genericReturn("Foo").with(returnType: String?.self)
        verify(mock, never()).genericReturn("Foo").with(returnType: Bool?.self)
        let message = TestUtils.catchCuckooFail {
            verifyNoMoreInteractions(mock)
        }
        #expect(message?.contains("1. genericReturn") == true, "\(message ?? "no failure")")
        #expect(message?.contains("2. ") == false)

        verify(mock).genericReturn("Foo").with(returnType: Int?.self)
        verifyNoMoreInteractions(mock)

        let otherTypes = TestUtils.catchCuckooFail {
            verify(mock).genericReturn("Foo").with(returnType: Bool?.self)
        }
        #expect(otherTypes?.contains("genericReturn(_:) was called only with other types") == true, "\(otherTypes ?? "no failure")")
        #expect(otherTypes?.contains("1. (String) -> Optional<String>") == true)
        #expect(otherTypes?.contains("2. (String) -> Optional<Int>") == true)
        #expect(otherTypes?.contains("3. ") == false)
    }
}
