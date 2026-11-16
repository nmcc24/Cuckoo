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
            Wanted 2 times but invoked 1 time.
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
            Wanted 1 time but not invoked.
            noReturn() wasn't called. The mock received:
              1. count("b")
            """,
        ])
    }

    @Test
    func aStringArgumentThatLooksLikeATupleIsQuoted() {
        let mock = MockTestedClass()
        stub(mock) { stub in
            when(stub.count(characters: any())).thenReturn(0)
        }
        _ = mock.count(characters: "(a, b)")

        let messages = collectingMessages {
            verify(mock).noReturn()
        }
        #expect(messages == [
            """
            Wanted 1 time but not invoked.
            noReturn() wasn't called. The mock received:
              1. count("(a, b)")
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
            No stub for count(characters:) with ("b").
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
            No stub for count(characters:) with ("b").
            The mock has no stub for count(characters:).
            """,
        ])
    }

    @Test
    func aGenericMemberStubbedForOtherTypesSaysSo() {
        let mock = MockGenericMethodClass<String>()
        stub(mock) { stub in
            when(stub.genericReturn(any())).thenReturn("a")
        }

        let messages = collectingMessages {
            let _: Int? = mock.genericReturn("1")
        }
        #expect(messages.count == 1)
        #expect(messages.first?.hasSuffix(
            """
            genericReturn(_:) with ("1").
            Stubs of genericReturn(_:) made for other types, which can't answer a call with (String) -> Optional<Int>:
              1. (String) -> Optional<String>
            """
        ) == true, "\(messages)")

        // The list of calls a failed verify shows names the member without its generic parameters too.
        let listed = collectingMessages {
            verify(mock).method(param: "x")
        }
        #expect(listed.first?.hasSuffix("  1. genericReturn(\"1\")") == true, "\(listed)")
    }

    @Test
    func aSingleFunctionTypedParameterIsParenthesizedInTheStubsTypes() {
        #expect(ConcreteStub<(String) -> Int, Void, Never, Void>.types(in: ((String) -> Int).self, out: Void.self) == "((String) -> Int) -> ()")
        #expect(ConcreteStub<(String, Int), Int, Never, Void>.types(in: (String, Int).self, out: Int.self) == "(String, Int) -> Int")
        #expect(ConcreteStub<Void, Int, Never, Void>.types(in: Void.self, out: Int.self) == "() -> Int")
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
    func signaturesOfGenericMethodsLeaveOutTheGenericParameters() {
        let signature = MemberSignature("genericReturn<W: Codable> (_ p0: String) -> W?")
        #expect(signature.name == "genericReturn(_:)")
        let nested = MemberSignature("pairs<C: Collection<(Int, Int)>>(of p0: C) -> Int")
        #expect(nested.name == "pairs(of:)")
        #expect(nested.argument(at: 0) == "`of:`")
        #expect(MemberSignature("static <(_ p0: Self, _ p1: Self) -> Bool").name == "static <(_:_:)")
        #expect(MemberSignature("static <~>(_ p0: Self, _ p1: Int) -> Bool").name == "static <~>(_:_:)")
        #expect(MemberSignature("static make<T> () -> T").name == "static make()")
    }

    @Test
    func signaturesOfPropertiesAndSubscripts() {
        #expect(MemberSignature("readWriteProperty#get").name == "readWriteProperty")
        #expect(MemberSignature("readWriteProperty#set").argument(at: 0) == "the new value")
        let setter = MemberSignature("subscript(_ p0: Int) -> String#set")
        #expect(setter.name == "subscript(_:)")
        #expect(setter.argument(at: 1) == "the new value")
    }

    @Test
    func callsAreNamedAsATestWritesThem() {
        let getter = ConcreteStubCall(method: "readWriteProperty#get", parameters: ())
        #expect(getter.readableDescription == "readWriteProperty")
        #expect(getter.memberAndArguments == "the getter of readWriteProperty")
        let setter = ConcreteStubCall(method: "readWriteProperty#set", parameters: 1)
        #expect(setter.readableDescription == "readWriteProperty = 1")
        #expect(setter.memberAndArguments == "the setter of readWriteProperty with (1)")
        let subscriptSetter = ConcreteStubCall(method: "subscript(_ p0: Int) -> String#set", parameters: (0, "a"))
        #expect(subscriptSetter.readableDescription == "[0] = \"a\"")
        #expect(ConcreteStubCall(method: "subscript(_ p0: Int) -> String#get", parameters: 0).readableDescription == "[0]")
        let tupleSetter = ConcreteStubCall(method: "pair#set", parameters: (1, 2))
        #expect(tupleSetter.readableDescription == "pair = (1, 2)")
        #expect(subscriptSetter.memberAndArguments == "the setter of subscript(_:) with (0, \"a\")")
        let method = ConcreteStubCall(method: "count(characters p0: String) -> Int", parameters: "b")
        #expect(method.readableDescription == "count(\"b\")")
        #expect(method.memberAndArguments == "count(characters:) with (\"b\")")
        #expect(ConcreteStubCall(method: "noReturn()", parameters: ()).memberAndArguments == "noReturn()")
        #expect(ConcreteStubCall(method: "resubscript(_ p0: Int)", parameters: 1).readableDescription == "resubscript(1)")
    }

    /// The failures `body` reports, without failing the test.
    private func collectingMessages(_ body: () -> Void) -> [String] {
        let messages = Locked<[String]>([])
        var configuration = CuckooConfiguration.current
        configuration.failureHandler = { failure in
            messages.withLock { $0.append(failure.message) }
        }
        CuckooConfiguration.$current.withValue(configuration) {
            body()
        }
        return messages.withLock { $0 }
    }
}
