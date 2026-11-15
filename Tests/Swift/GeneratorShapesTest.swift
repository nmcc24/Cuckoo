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

    /// A member with an `isolated` parameter runs on the actor it's given, and its stub sees the argument.
    @Test
    @MainActor
    func isolatedParameterIsPassedToTheStub() async {
        let mock = MockIsolatedWork()
        stub(mock) { stub in
            when(stub.run(isolation: any())).then { isolation in isolation === MainActor.shared ? 1 : 0 }
        }

        let result = await mock.run(isolation: #isolation)
        #expect(result == 1)
        verify(mock).run(isolation: any())
    }

    /// `nonisolated(nonsending)` and `@concurrent` members are stubbed and verified like any async member.
    @Test
    func nonsendingAndConcurrentMembers() async {
        let mock = MockNonsendingLoader()
        stub(mock) { stub in
            when(stub.load()).thenReturn(1)
            when(stub.compute()).thenReturn(2)
        }

        let loaded = await mock.load()
        let computed = await mock.compute()
        #expect(loaded == 1)
        #expect(computed == 2)
        verify(mock).load()
        verify(mock).compute()
    }

    /// A plain protocol's `@MainActor` members are stubbed and called on the main actor.
    @Test
    @MainActor
    func mainActorMembersOfAPlainProtocol() {
        let mock = MockMainActorMembers()
        stub(mock) { stub in
            when(stub.lastEvent.get).thenReturn("opened")
            when(stub.track(event: any())).thenDoNothing()
        }

        mock.track(event: "opened")
        #expect(mock.lastEvent == "opened")
        verify(mock).track(event: "opened")
        verify(mock).lastEvent.get()
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
