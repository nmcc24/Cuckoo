import Testing
import Cuckoo
@testable import CuckooMocks
@testable import CuckooTestSources

struct ArgumentCaptorTest {
    @Test
    func multipleCalls() {
        let mock = MockTestedClass()
        stub(mock) { mock in
            when(mock.readWriteProperty.set(any())).thenDoNothing()
        }
        mock.readWriteProperty = 10
        mock.readWriteProperty = 20
        mock.readWriteProperty = 30
        let captor = ArgumentCaptor<Int>()
        
        verify(mock, times(3)).readWriteProperty.set(captor.capture())
        
        #expect(captor.value == 30)
        #expect(captor.allValues == [10, 20, 30])
    }

    @Test
    func noCall() {
        let mock = MockTestedClass()
        let captor = ArgumentCaptor<Int>()
        
        verify(mock, never()).readWriteProperty.set(captor.capture())
        
        #expect(captor.value == nil)
        #expect(captor.allValues.isEmpty)
    }

    /// A captor of a non-`Sendable` type gets the `ParameterMatcher` overload, which captures the same way.
    @Test
    func capturesValuesThatArentSendable() {
        final class Box {}
        let captor = ArgumentCaptor<Box>()
        let first = Box()
        let second = Box()

        let matcher: ParameterMatcher<Box> = captor.capture()
        #expect(matcher.matches(first))
        #expect(matcher.matches(second))

        #expect(captor.value === second)
        #expect(captor.allValues.count == 2 && captor.allValues.first === first)
    }

    /// Handing the captor to another task compiles only because it's `Sendable`.
    @Test
    func isSendableWhenItsValuesAre() async {
        let captor = ArgumentCaptor<Int>()
        await Task.detached {
            _ = captor.capture().matches(1)
        }.value
        #expect(captor.allValues == [1])
    }

    @Test
    func capturesOnlyCallsEveryMatcherAccepts() {
        let mock = MockTestedClass()
        stub(mock) { stub in
            when(stub.withLabelAndUnderscore(labelA: any(), any())).thenDoNothing()
        }
        mock.withLabelAndUnderscore(labelA: "1", "x")
        mock.withLabelAndUnderscore(labelA: "5", "y")
        let captor = ArgumentCaptor<String>()

        verify(mock).withLabelAndUnderscore(labelA: captor.capture(), "y")

        #expect(captor.allValues == ["5"])
    }

    @Test
    func failedVerificationCapturesNothing() {
        let mock = MockTestedClass()
        stub(mock) { stub in
            when(stub.readWriteProperty.set(any())).thenDoNothing()
        }
        mock.readWriteProperty = 10
        mock.readWriteProperty = 20
        let captor = ArgumentCaptor<Int>()

        let failure = TestUtils.catchCuckooFail {
            verify(mock, times(3)).readWriteProperty.set(captor.capture())
        }

        #expect(failure != nil)
        #expect(captor.allValues.isEmpty)
    }

    @Test
    func stubCapturesOnlyTheCallsItAnswers() {
        let mock = MockTestedClass()
        let captor = ArgumentCaptor<String>()
        stub(mock) { stub in
            when(stub.withLabelAndUnderscore(labelA: any(), any())).thenDoNothing()
            when(stub.withLabelAndUnderscore(labelA: captor.capture(), "y")).thenDoNothing()
        }

        mock.withLabelAndUnderscore(labelA: "1", "x")
        mock.withLabelAndUnderscore(labelA: "5", "y")

        #expect(captor.allValues == ["5"])
    }

    @Test
    func inOrderCapturesTheCallsItTakes() {
        let mock = MockTestedClass()
        stub(mock) { stub in
            when(stub.readWriteProperty.set(any())).thenDoNothing()
            when(stub.noReturn()).thenDoNothing()
        }
        mock.readWriteProperty = 10
        mock.noReturn()
        mock.readWriteProperty = 20
        let captor = ArgumentCaptor<Int>()

        inOrder {
            verify(mock).noReturn()
            verify(mock).readWriteProperty.set(captor.capture())
        }

        #expect(captor.allValues == [20])
    }
}
