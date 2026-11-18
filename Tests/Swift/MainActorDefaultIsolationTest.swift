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
            when(stub.greet(any())).then { person in
                // Fails if the mock weren't isolated to the main actor, as its type is.
                MainActor.assertIsolated()
                return "Hello, \(person)"
            }
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
            when(stub.increment(by: 1)).then { _ in
                MainActor.assertIsolated()
                return 10
            }
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

    /// In a class that's nonisolated through its superclass, the member implementing a default-isolated protocol's
    /// requirement is on the main actor, as Swift infers it, and the others aren't.
    @Test
    @MainActor
    func aWitnessInANonisolatedClassIsMockedOnItsRequirementsActor() {
        let mock = MockWitnessingScreen()
        stub(mock) { stub in
            when(stub.show()).then {
                MainActor.assertIsolated()
                return "stubbed"
            }
            when(stub.describe()).thenReturn("mock")
            when(stub.own()).thenReturn(2)
        }

        #expect(mock.show() == "stubbed")
        #expect(Self.callingOffTheMainActor(mock) == "mock2")
        verify(mock).show()
        verify(mock).describe()
        verify(mock).own()
    }

    /// Compiles only while these members are nonisolated.
    private nonisolated static func callingOffTheMainActor(_ mock: MockWitnessingScreen) -> String {
        mock.describe() + String(mock.own())
    }
}
