import Testing
@testable import Cuckoo
@testable import CuckooMocks
@testable import CuckooTestSources

/// Members declared `throws(E)`: the mock throws only `E`, from `thenThrow` or a `then` closure, and an unstubbed
/// call, which can't throw `CuckooError` as an `E`, returns the default value after recording the failure.
struct TypedThrowsTest {
    private let mock = MockClassWithTypedThrows()

    @Test
    func thenThrowThrowsTheTypedError() {
        stub(mock) { stub in
            when(stub.typedThrows()).thenThrow(.failed)
        }

        #expect(throws: ClassWithTypedThrows.Error.failed) {
            _ = try mock.typedThrows()
        }
        verify(mock).typedThrows()
    }

    @Test
    func thenClosureThrowsTheTypedError() {
        stub(mock) { stub in
            when(stub.typedThrows()).then { throw ClassWithTypedThrows.Error.failed }
        }

        do {
            _ = try mock.typedThrows()
            Issue.record("Expected a throw")
        } catch {
            // The catch's type is the member's error type, so this compiles only if the mock keeps `throws(Error)`.
            #expect(error == .failed)
        }
    }

    @Test
    func returnsAfterThrowingInOrder() throws {
        stub(mock) { stub in
            when(stub.typedThrows()).thenThrow(.failed).thenReturn(3)
        }

        #expect(throws: ClassWithTypedThrows.Error.failed) {
            _ = try mock.typedThrows()
        }
        #expect(try mock.typedThrows() == 3)
    }

    @Test
    func genericMemberThrowsItsErrorType() {
        stub(mock) { stub in
            when(stub.genericWithTypedThrows(any(Int.self))).thenThrow(StubError())
        }

        #expect(throws: StubError.self) {
            try mock.genericWithTypedThrows(1)
        }
        verify(mock).genericWithTypedThrows(any(Int.self))
    }

    @Test
    func asyncMemberThrowsTheTypedError() async {
        stub(mock) { stub in
            when(stub.asyncTypedThrow()).thenThrow(.failed)
            when(stub.asyncGenericWithTypedThrows(any(String.self))).thenThrow(StubError())
        }

        await #expect(throws: ClassWithTypedThrows.Error.failed) {
            _ = try await mock.asyncTypedThrow()
        }
        await #expect(throws: StubError.self) {
            try await mock.asyncGenericWithTypedThrows("a")
        }
    }

    @Test
    func unstubbedCallRecordsAFailureAndReturnsTheDefault() throws {
        let failure = TestUtils.catchCuckooFail {
            #expect((try? mock.typedThrows()) == .some(nil))
        }
        #expect(failure?.hasPrefix("No stub for method `typedThrows()") == true)
    }
}
