import Testing
import Cuckoo
@testable import CuckooMocks
@testable import CuckooMainActorTestSources

/// Mocks of a module built with MainActor default isolation, which the Swift 6 matrix only compiles.
struct MainActorDefaultIsolationTests {
    @Test
    @MainActor
    func aProtocolStatingNoIsolationIsMockedOnTheMainActor() {
        let mock = MockDefaultIsolatedGreeter()
        stub(mock) { stub in
            when(stub.name.get).thenReturn("Ann")
            when(stub.greet(any())).then { person in "Hello, \(person)" }
        }

        #expect(mock.name == "Ann")
        #expect(mock.greet("Bo") == "Hello, Bo")
        verify(mock).name.get()
        verify(mock).greet("Bo")
        verifyNoMoreInteractions(mock)
    }

    @Test
    @MainActor
    func aClassStatingNoIsolationIsMockedOnTheMainActor() {
        let mock = MockDefaultIsolatedCounter().withEnabledSuperclassSpy()
        stub(mock) { stub in
            when(stub.increment(by: 1)).thenReturn(10)
        }

        #expect(mock.increment(by: 1) == 10)
        #expect(mock.increment(by: 2) == 2)
        verify(mock, times(2)).increment(by: any())
    }

    @Test
    func aNonisolatedProtocolIsMockedOffTheMainActor() async {
        let mock = MockNonisolatedClock()
        stub(mock) { stub in
            when(stub.now()).thenReturn(42)
        }

        let now = await Task.detached { mock.now() }.value
        #expect(now == 42)
        verify(mock).now()
    }
}
