import Testing
import Cuckoo
@testable import CuckooMocks
@testable import CuckooTestSources

/// A variadic argument reaches matchers, captors and `then` closures as an array.
struct VariadicTest {
    @Test
    func stubsAndVerifiesAVariadicArgumentAsAnArray() {
        let mock = MockVariadicLogger()
        stub(mock) { stub in
            when(stub.log(equal(to: ["a", "b"]), level: any())).thenReturn(2)
            when(stub.log(equal(to: []), level: any())).thenReturn(0)
        }

        #expect(mock.log("a", "b", level: 1) == 2)
        #expect(mock.log(level: 3) == 0)

        verify(mock).log(equal(to: ["a", "b"]), level: equal(to: 1))
        verify(mock).log(equal(to: []), level: equal(to: 3))
        verifyNoMoreInteractions(mock)
    }

    @Test
    func thenClosureReceivesTheArray() async throws {
        let mock = MockVariadicLogger()
        stub(mock) { stub in
            when(stub.sum(any())).then { values in values.reduce(0, +) }
        }

        #expect(try await mock.sum(1, 2, 3) == 6)
        verify(mock).sum(equal(to: [1, 2, 3]))
    }

    @Test
    func captorCapturesTheArray() {
        let mock = MockVariadicLogger()
        stub(mock) { stub in
            when(stub.log(any(), level: any())).thenReturn(0)
        }
        _ = mock.log("x", "y", level: 0)

        let captor = ArgumentCaptor<[String]>()
        verify(mock).log(captor.capture(), level: any())
        #expect(captor.value == ["x", "y"])
    }

    @Test
    func classMockStubsAVariadicMethod() {
        let mock = MockVariadicFormatter()
        stub(mock) { stub in
            when(stub.join(equal(to: ["a", "b"]), separator: equal(to: "-"))).thenReturn("stubbed")
        }

        #expect(mock.join("a", "b", separator: "-") == "stubbed")
        verify(mock).join(equal(to: ["a", "b"]), separator: equal(to: "-"))
    }
}
