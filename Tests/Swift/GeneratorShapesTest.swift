import Testing
import Cuckoo
@testable import CuckooMocks
@testable import CuckooTestSources

struct GeneratorShapesTest {
    /// A typed-throws getter keeps its error type: a stubbed error of that type reaches the caller as it is.
    @Test
    func typedThrowingGetterThrowsTheStubbedError() {
        let mock = MockTypedThrowingStore()
        stub(mock) { stub in
            when(stub.value.get).thenThrow(ShapeFailure.failed)
        }

        #expect(throws: ShapeFailure.failed) {
            _ = try mock.value
        }
        verify(mock).value.get()
    }

    /// A `nonisolated` member of a `@MainActor` protocol is stubbed with `Sendable` closures, so it can be called
    /// from any isolation.
    @Test
    @MainActor
    func nonisolatedMemberOfMainActorProtocolIsCallableAnywhere() async {
        let mock = MockMainActorIdentified()
        stub(mock) { stub in
            when(stub.identifier()).then { "stubbed" }
        }

        let identifier = await Task.detached { mock.identifier() }.value
        #expect(identifier == "stubbed")
        verify(mock).identifier()
    }

    /// A class mock keeps the default argument values, so a call can still leave them out.
    @Test
    func classMockKeepsDefaultArguments() {
        let mock = MockDefaultArgumentCounter()
        stub(mock) { stub in
            when(stub.count(level: equal(to: 1), times: equal(to: 2))).thenReturn(7)
        }

        #expect(mock.count() == 7)
        verify(mock).count(level: equal(to: 1), times: equal(to: 2))
    }
}
