import Testing
@testable import Cuckoo
@testable import CuckooMocks
@testable import CuckooTestSources

struct DiagnosticsTests {
    @Test
    func aFailedVerifyNamesTheArgumentThatDiffers() {
        let mock = MockTestedClass()
        stub(mock) { stub in
            when(stub.withLabelAndUnderscore(labelA: any(), any())).thenDoNothing()
        }
        mock.withLabelAndUnderscore(labelA: "a", "b")
        mock.withLabelAndUnderscore(labelA: "x", "c")
        mock.withLabelAndUnderscore(labelA: "a", "c")

        let messages = collectingMessages {
            verify(mock).withLabelAndUnderscore(labelA: "a", "b")
            verify(mock, times(2)).withLabelAndUnderscore(labelA: "a", "c")
        }
        #expect(messages == [
            """
            Wanted 2 times but invoked 1 times.
            Calls to withLabelAndUnderscore(labelA:_:):
              1. withLabelAndUnderscore("a", "b"): argument 2 doesn't match
              2. withLabelAndUnderscore("x", "c"): `labelA:` doesn't match
              3. withLabelAndUnderscore("a", "c") matches
            """,
        ])
    }

    @Test
    func aFailedVerifyOfAnUncalledMemberListsTheMocksCalls() {
        let mock = MockTestedClass()
        stub(mock) { stub in
            when(stub.count(characters: any())).thenReturn(0)
        }
        _ = mock.count(characters: "b")

        let messages = collectingMessages {
            verify(mock).noReturn()
        }
        #expect(messages == [
            """
            Wanted 1 times but not invoked.
            noReturn() wasn't called. The mock received:
              1. count("b")
            """,
        ])
    }

    @Test
    func anUnmatchedCallNamesTheArgumentEachStubRejected() {
        let mock = MockTestedClass()
        stub(mock) { stub in
            when(stub.count(characters: "a")).thenReturn(1)
            when(stub.count(characters: "c")).thenReturn(2)
        }

        let messages = collectingMessages {
            _ = mock.count(characters: "b")
        }
        #expect(messages == [
            """
            No stub for method `count(characters p0: String) -> Int` using parameters b.
            Stubs of count(characters:), newest first:
              1. `characters:` doesn't match
              2. `characters:` doesn't match
            """,
        ])
    }

    @Test
    func anUnstubbedMemberSaysItHasNoStub() {
        let mock = MockTestedClass()

        let messages = collectingMessages {
            _ = mock.count(characters: "b")
        }
        #expect(messages == [
            """
            No stub for method `count(characters p0: String) -> Int` using parameters b.
            The mock has no stub for count(characters:).
            """,
        ])
    }

    @Test
    func signaturesKeepCommasInsideTypesTogether() {
        let signature = MemberSignature("withOptionalClosure(_ p0: String, closure p1: ((String, Int) -> Void)?, map p2: [String: Int]) -> Int")
        #expect(signature.name == "withOptionalClosure(_:closure:map:)")
        #expect(signature.argument(at: 0) == "argument 1")
        #expect(signature.argument(at: 1) == "`closure:`")
        #expect(signature.argument(at: 2) == "`map:`")
        #expect(signature.argument(at: 3) == "argument 4")
    }

    @Test
    func signaturesOfPropertiesAndSubscripts() {
        #expect(MemberSignature("readWriteProperty#get").name == "readWriteProperty")
        #expect(MemberSignature("readWriteProperty#set").argument(at: 0) == "the new value")
        let setter = MemberSignature("subscript(_ p0: Int) -> String#set")
        #expect(setter.name == "subscript(_:)")
        #expect(setter.argument(at: 1) == "the new value")
    }

    /// The failures `body` reports, without failing the test.
    private func collectingMessages(_ body: () -> Void) -> [String] {
        let messages = Locked<[String]>([])
        var configuration = CuckooConfiguration.current
        configuration.failureHandler = { message, _ in
            messages.withLock { $0.append(message) }
        }
        CuckooConfiguration.$current.withValue(configuration) {
            body()
        }
        return messages.withLock { $0 }
    }
}
