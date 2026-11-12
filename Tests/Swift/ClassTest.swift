import Testing
import Cuckoo
@testable import CuckooMocks
@testable import CuckooTestSources

extension TestedClass: Mocked {
    typealias MockType = MockTestedClass
}

struct ClassTest {

    private let mock = MockTestedClass()

    @Test
    func readOnlyPropertyWithMockCreator() {
        let mock = createMock(for: TestedClass.self) { builder, stub in
            when(stub.readOnlyProperty.get).thenReturn("a")

            return MockTestedClass()
        }

        #expect(mock.readOnlyProperty == "a")
        verify(mock).readOnlyProperty.get()
    }

    @Test
    func readOnlyProperty() {
        let mock = MockTestedClass()

        stub(mock) { mock in
            when(mock.readOnlyProperty.get).thenReturn("a")
        }

        #expect(mock.readOnlyProperty == "a")
        verify(mock).readOnlyProperty.get()
    }

    @Test
    func readOnlyOptionalProperty() {
        let mock = MockTestedClass()

        stub(mock) { mock in
            when(mock.readOnlyOptionalProperty.get).thenReturn("a")
        }

        #expect(mock.readOnlyOptionalProperty == "a")
        verify(mock).readOnlyOptionalProperty.get()
    }

    @Test
    func optionalReadOnlyPropertyIsNil() {
        let mock = MockTestedClass()

        stub(mock) { mock in
            when(mock.readOnlyOptionalProperty.get).thenReturn(nil)
        }

        #expect(mock.readOnlyOptionalProperty == nil)
        verify(mock).readOnlyOptionalProperty.get()
    }

    @Test
    func readWriteProperty() {
        var called = false
        stub(mock) { mock in
            when(mock.readWriteProperty.get).thenReturn(1)
            when(mock.readWriteProperty.set(anyInt())).then { _ in called = true }
        }

        mock.readWriteProperty = 0

        #expect(mock.readWriteProperty == 1)
        #expect(called)
        verify(mock).readWriteProperty.get()
        verify(mock).readWriteProperty.set(0)
    }

    @Test
    func optionalProperty() {
        var called = false
        stub(mock) { mock in
            when(mock.optionalProperty.get).thenReturn(nil)
            when(mock.optionalProperty.set(anyInt())).then { _ in called = true }
        }

        mock.optionalProperty = 0

        #expect(mock.optionalProperty == nil)
        #expect(called)
        verify(mock).optionalProperty.get()
        verify(mock).optionalProperty.set(equal(to: 0))
    }

    @Test
    func noReturn() {
        var called = false
        stub(mock) { mock in
            when(mock.noReturn()).then { _ in called = true }
        }

        mock.noReturn()

        #expect(called)
        verify(mock).noReturn()
    }

    @Test
    func countCharacters() {
        stub(mock) { mock in
            when(mock.count(characters: "a")).thenReturn(1)
        }

        #expect(mock.count(characters: "a") == 1)
        verify(mock).count(characters: "a")
    }

    @Test
    func withThrows() {
        stub(mock) { mock in
            when(mock.withThrows()).thenThrow(TestError.unknown)
        }

        var catched = false
        do {
            _ = try mock.withThrows()
        } catch {
            catched = true
        }

        #expect(catched)
        verify(mock).withThrows()
    }

    @Test
    func withNoReturnThrows() {
        stub(mock) { mock in
            when(mock.withNoReturnThrows()).thenThrow(TestError.unknown)
        }

        var catched = false
        do {
            try mock.withNoReturnThrows()
        } catch {
            catched = true
        }

        #expect(catched)
        verify(mock).withNoReturnThrows()
    }

    @Test
    func withClosure() {
        func anyNestedClosure<IN1, IN2, OUT>() -> ParameterMatcher<((IN1) -> IN2) -> OUT> {
            return ParameterMatcher()
        }

        stub(mock) { mock in
            when(mock.withClosure(anyClosure())).then { $0("a") }
            when(mock.withAutoClosure(action: anyClosure())).then { $0() }
            when(mock.withClosureReturningVoid(anyClosure())).then { $0("a")() }
            when(mock.withClosureReturningInt(anyClosure())).then { $0("a")(1) }
            when(mock.withOptionalClosureAlone(anyClosure())).then { $0?("a")(1) ?? 1 }
            when(mock.withNestedClosure1(anyClosure())).then { $0("a")({ Int($0) ?? 1 }) }
            when(mock.withNestedClosure2(anyNestedClosure())).then { $0({ Int($0) ?? 1 })({ Int($0) ?? 1 }) }
        }

        #expect(mock.withClosure { _ in 1 } == 1)
        #expect(mock.withAutoClosure(action: 1) == 1)
        #expect(mock.withClosureReturningVoid {_ in { return 1 } } == 1)
        #expect(mock.withClosureReturningInt { _ in { _ in return 1 } } == 1)
        #expect(mock.withOptionalClosureAlone { _ in { _ in return 1 } } == 1)
        #expect(mock.withNestedClosure1 { _ in { _ in return 1 } } == 1)
        #expect(mock.withNestedClosure2 { _ in { _ in return 1 } } == 1)

        verify(mock).withClosure(anyClosure())
        verify(mock).withAutoClosure(action: anyClosure())
        verify(mock).withClosureReturningVoid(anyClosure())
        verify(mock).withClosureReturningInt(anyClosure())
        verify(mock).withOptionalClosureAlone(anyClosure())
        verify(mock).withNestedClosure1(anyClosure())
        verify(mock).withNestedClosure2(anyNestedClosure())
    }

    @Test
    func withEscape() {
        var called = false
        stub(mock) { mock in
            when(mock.withEscape(anyString(), action: anyClosure())).then { text, closure in closure(text) }
        }

        mock.withEscape("a") { called = $0 == "a" }

        #expect(called)
        verify(mock).withEscape(anyString(), action: anyClosure())
    }

    @Test
    func withOptionalClosure() {
        var called = false
        stub(mock) { mock in
            when(mock.withOptionalClosure(anyString(), closure: anyClosure())).then { text, closure in closure?(text)  }
        }

        mock.withOptionalClosure("a") { called = $0 == "a" }

        #expect(called)
        verify(mock).withOptionalClosure(anyString(), closure: anyClosure())
    }

    @Test
    func withLabel() {
        var called = false
        stub(mock) { mock in
            when(mock.withLabelAndUnderscore(labelA: anyString(), anyString())).then { _ in called = true }
        }

        mock.withLabelAndUnderscore(labelA: "a", "b")
        #expect(called)
        verify(mock).withLabelAndUnderscore(labelA: anyString(), anyString())
    }

    @Test
    func callingCountCharactersMethodWithHello() {
        stub(mock) { mock in
            when(mock.callingCountCharactersMethodWithHello()).thenCallRealImplementation()
            when(mock.count(characters: any())).thenReturn(0)
        }

        #expect(mock.callingCountCharactersMethodWithHello() == 0)
        verify(mock).callingCountCharactersMethodWithHello()
        verify(mock).count(characters: "Hello")
    }

    @Test
    func defaultImplCall() {
        mock.enableDefaultImplementation(TestedClassStub())

        #expect(mock.callingCountCharactersMethodWithHello() == 0)
        verify(mock).callingCountCharactersMethodWithHello()
    }

    @Test
    func testInout() {
        let mock = MockInoutMethodClass()
        var received: Int?
        stub(mock) { mock in
            when(mock.inoutko(param: anyInt())).then { param in
                received = param
            }
        }

        var integer = 12
        mock.inoutko(param: &integer)

        #expect(received == 12)
        verify(mock).inoutko(param: 12)
    }

    @Test
    func optionals() {
        let mock = MockOptionalParamsClass()

        stub(mock) { mock in
            when(mock.clashingFunction(param1: Optional(1), param2: "Henlo Fren") as Cuckoo.ClassStubNoReturnFunction<(Int?, String), _, _>).thenDoNothing()
            when(mock.clashingFunction(param1: Optional.none, param2: "Henlo Fren") as Cuckoo.ClassStubNoReturnFunction<(Int?, String), _, _>).thenDoNothing()
            when(mock.clashingFunction(param1: anyInt(), param2: "What's the question?") as Cuckoo.ClassStubNoReturnFunction<(Int, String?), _, _>).then {
                print("What's 6 times 9? \($0.0)")
            }
            when(mock.clashingFunction(param1: anyInt(), param2: isNil()) as Cuckoo.ClassStubNoReturnFunction<(Int, String?), _, _>).then {
                print("What's 6 times 9? \($0.0)")
            }
            when(mock.function(param: any())).thenDoNothing()
            when(mock.function(param: any())).thenDoNothing()
            when(mock.function(param: "string")).thenDoNothing()
            when(mock.functionClosure(param: any())).thenDoNothing()
            when(mock.implicitOptionalProperty.set(any())).thenDoNothing()
            when(mock.implicitOptionalProperty.get).thenReturn(nil)
            when(mock.functionImplicit(param: any())).thenDoNothing()
        }

        mock.function(param: nil)
        mock.clashingFunction(param1: Optional(1), param2: "Henlo Fren")
        mock.clashingFunction(param1: nil, param2: "Henlo Fren")
        mock.clashingFunction(param1: 42, param2: Optional("What's the question?"))
        mock.implicitOptionalProperty = 10
        _ = mock.implicitOptionalProperty
        mock.functionImplicit(param: "Implicits are obsolete.")

        verify(mock).function(param: any())
        _ = verify(mock).clashingFunction(param1: anyInt(), param2: "Henlo Fren") as Cuckoo.__DoNotUse<(Int?, String), Void>
        _ = verify(mock).clashingFunction(param1: isNil(), param2: "Henlo Fren") as Cuckoo.__DoNotUse<(Int?, String), Void>
        _ = verify(mock).clashingFunction(param1: 42, param2: "What's the question?") as Cuckoo.__DoNotUse<(Int, String?), Void>
        verify(mock).implicitOptionalProperty.get()
        verify(mock).implicitOptionalProperty.set(any())
        verify(mock).functionImplicit(param: any())
    }

    @Test
    func closureN() {
        let mock = MockClosureNClass()
        stub(mock) { mock in
            when(mock.f0(closure: anyClosure())).then { closure in
                closure()
            }
            when(mock.f1(closure: anyClosure())).then { closure in
                _ = closure("Hello")
            }
            when(mock.f2(closure: anyClosure())).then { closure in
                _ = closure("Cuckoo", 7)
            }
            when(mock.f3(closure: anyClosure())).then { closure in
                _ = closure("World", 1, true)
            }
            when(mock.f4(closure: anyClosure())).then { closure in
                _ = closure("Dude", 0, false, Optional(["Hello", "World"])) ?? ["defaultko"]
            }
            when(mock.f5(closure: anyClosure())).then { closure in
                _ = closure("How", 2, true, nil, Set([1, 2, 3]))
            }
            when(mock.f6(closure: anyClosure())).then { closure in
                _ = closure("Are", 5, true, nil, Set([1, 2, 3]), ())
            }
            when(mock.f7(closure: anyClosure())).then { closure in
                _ = closure("You", 13, false, nil, Set([1, 2]), (), ["hello": "world"])
            }
        }

        mock.f0(closure: { })
        mock.f1(closure: { $0 })
        mock.f2(closure: { $1 })
        mock.f3(closure: { $2 })
        mock.f4(closure: { $3 })
        mock.f5(closure: { $4 })
        mock.f6(closure: { $5 })
        mock.f7(closure: { $6 })

        verify(mock).f0(closure: anyClosure())
        verify(mock).f1(closure: anyClosure())
        verify(mock).f2(closure: anyClosure())
        verify(mock).f3(closure: anyClosure())
        verify(mock).f4(closure: anyClosure())
        verify(mock).f5(closure: anyClosure())
        verify(mock).f6(closure: anyClosure())
        verify(mock).f7(closure: anyClosure())
    }

    @Test
    func closureNThrowing() {
        let mock = MockClosureNThrowingClass()
        stub(mock) { mock in
            when(mock.f0(closure: anyThrowingClosure())).then { closure in
                _ = try? closure()
            }
            when(mock.f1(closure: anyThrowingClosure())).then { closure in
                _ = try? closure("Hello")
            }
            when(mock.f2(closure: anyThrowingClosure())).then { closure in
                _ = try? closure("Cuckoo", 7)
            }
            when(mock.f3(closure: anyThrowingClosure())).then { closure in
                _ = try? closure("World", 1, true)
            }
            when(mock.f4(closure: anyThrowingClosure())).then { closure in
                _ = try? closure("Dude", 0, false, Optional(["Hello", "World"]))
            }
            when(mock.f5(closure: anyThrowingClosure())).then { closure in
                _ = try? closure("How", 2, true, nil, Set([1, 2, 3]))
            }
            when(mock.f6(closure: anyThrowingClosure())).then { closure in
                _ = try? closure("Are", 5, true, nil, Set([1, 2, 3]), ())
            }
            when(mock.f7(closure: anyThrowingClosure())).then { closure in
                _ = try? closure("You", 13, false, nil, Set([1, 2]), (), ["hello": "world"])
            }
        }

        mock.f0(closure: { })
        mock.f1(closure: { $0 })
        mock.f2(closure: { $1 })
        mock.f3(closure: { $2 })
        mock.f4(closure: { $3 })
        mock.f5(closure: { $4 })
        mock.f6(closure: { $5 })
        mock.f7(closure: { $6 })

        verify(mock).f0(closure: anyThrowingClosure())
        verify(mock).f1(closure: anyThrowingClosure())
        verify(mock).f2(closure: anyThrowingClosure())
        verify(mock).f3(closure: anyThrowingClosure())
        verify(mock).f4(closure: anyThrowingClosure())
        verify(mock).f5(closure: anyThrowingClosure())
        verify(mock).f6(closure: anyThrowingClosure())
        verify(mock).f7(closure: anyThrowingClosure())
    }

    @Test
    func closureNThrowingThrows() {
        let mock = MockClosureNThrowingThrowsClass()
        stub(mock) { mock in
            when(mock.f0(closure: anyThrowingClosure())).then { closure in
                try closure()
            }
            when(mock.f1(closure: anyThrowingClosure())).then { closure in
                _ = try closure("Hello")
            }
            when(mock.f2(closure: anyThrowingClosure())).then { closure in
                _ = try closure("Cuckoo", 7)
            }
            when(mock.f3(closure: anyThrowingClosure())).then { closure in
                _ = try closure("World", 1, true)
            }
            when(mock.f4(closure: anyThrowingClosure())).then { closure in
                _ = try closure("Dude", 0, false, Optional(["Hello", "World"])) ?? ["defaultko"]
            }
            when(mock.f5(closure: anyThrowingClosure())).then { closure in
                _ = try closure("How", 2, true, nil, Set([1, 2, 3]))
            }
            when(mock.f6(closure: anyThrowingClosure())).then { closure in
                _ = try closure("Are", 5, true, nil, Set([1, 2, 3]), ())
            }
            when(mock.f7(closure: anyThrowingClosure())).then { closure in
                _ = try closure("You", 13, false, nil, Set([1, 2]), (), ["hello": "world"])
            }
        }

        struct Erre: Error {

        }

        #expect(throws: TestError.self, "Expected thrown TestError.") { try mock.f0(closure: { throw TestError.unknown }) }
        #expect(throws: TestError.self, "Expected thrown TestError.") { try mock.f1(closure: { _ in throw TestError.unknown }) }
        #expect(throws: TestError.self, "Expected thrown TestError.") { try mock.f2(closure: { _, _ in throw TestError.unknown }) }
        #expect(throws: TestError.self, "Expected thrown TestError.") { try mock.f3(closure: { _, _, _ in throw TestError.unknown }) }
        #expect(throws: TestError.self, "Expected thrown TestError.") { try mock.f4(closure: { _, _, _, _ in throw TestError.unknown }) }
        #expect(throws: TestError.self, "Expected thrown TestError.") { try mock.f5(closure: { _, _, _, _, _ in throw TestError.unknown }) }
        #expect(throws: TestError.self, "Expected thrown TestError.") { try mock.f6(closure: { _, _, _, _, _, _ in throw TestError.unknown }) }
        #expect(throws: TestError.self, "Expected thrown TestError.") { try mock.f7(closure: { _, _, _, _, _, _, _ in throw TestError.unknown }) }

        verify(mock).f0(closure: anyThrowingClosure())
        verify(mock).f1(closure: anyThrowingClosure())
        verify(mock).f2(closure: anyThrowingClosure())
        verify(mock).f3(closure: anyThrowingClosure())
        verify(mock).f4(closure: anyThrowingClosure())
        verify(mock).f5(closure: anyThrowingClosure())
        verify(mock).f6(closure: anyThrowingClosure())
        verify(mock).f7(closure: anyThrowingClosure())
    }

    @Test
    func closureNRehrowing() {
        let mock = MockClosureNRethrowingClass()
        stub(mock) { mock in
            when(mock.f0(closure: anyThrowingClosure())).then { closure in
                _ = try closure()
            }
            when(mock.f1(closure: anyThrowingClosure())).then { closure in
                _ = try? closure("Hello")
            }
            when(mock.f2(closure: anyThrowingClosure())).then { closure in
                _ = try closure("Cuckoo", 7)
            }
            when(mock.f3(closure: anyThrowingClosure())).then { closure in
                _ = try? closure("World", 1, true)
            }
            when(mock.f4(closure: anyThrowingClosure())).then { closure in
                _ = try closure("Dude", 0, false, Optional(["Hello", "World"])) ?? ["defaultko"]
            }
            when(mock.f5(closure: anyThrowingClosure())).then { closure in
                _ = try? closure("How", 2, true, nil, Set([1, 2, 3]))
            }
            when(mock.f6(closure: anyThrowingClosure())).then { closure in
                _ = try closure("Are", 5, true, nil, Set([1, 2, 3]), ())
            }
            when(mock.f7(closure: anyThrowingClosure())).then { closure in
                _ = try? closure("You", 13, false, nil, Set([1, 2]), (), ["hello": "world"])
            }
        }

        // testing that when the closure is not throwing, no need to call it with `try`
        mock.f0(closure: { })
        mock.f1(closure: { $0 })
        mock.f2(closure: { $1 })
        mock.f3(closure: { $2 })
        mock.f4(closure: { $3 })
        mock.f5(closure: { $4 })
        mock.f6(closure: { $5 })
        mock.f7(closure: { $6 })

        // testing the cases where stub calls closure with `try`
        #expect(throws: TestError.self, "Expected thrown TestError.") { try mock.f0(closure: { throw TestError.unknown }) }
        #expect(throws: TestError.self, "Expected thrown TestError.") { try mock.f2(closure: { _, _ in throw TestError.unknown }) }
        #expect(throws: TestError.self, "Expected thrown TestError.") { try mock.f4(closure: { _, _, _, _ in throw TestError.unknown }) }
        #expect(throws: TestError.self, "Expected thrown TestError.") { try mock.f6(closure: { _, _, _, _, _, _ in throw TestError.unknown }) }

        verify(mock, times(2)).f0(closure: anyThrowingClosure())
        verify(mock).f1(closure: anyThrowingClosure())
        verify(mock, times(2)).f2(closure: anyThrowingClosure())
        verify(mock).f3(closure: anyThrowingClosure())
        verify(mock, times(2)).f4(closure: anyThrowingClosure())
        verify(mock).f5(closure: anyThrowingClosure())
        verify(mock, times(2)).f6(closure: anyThrowingClosure())
        verify(mock).f7(closure: anyThrowingClosure())
    }

    @Test
    func typeGuesser() {
        let original = TypeIsRightClass()
        let mock = MockTypeIsRightClass()
        mock.enableDefaultImplementation(original)

        #expect(String(describing: type(of: mock.stringo)) == String(describing: type(of: original.stringo)))
        #expect(String(describing: type(of: mock.stringyStringo)) == String(describing: type(of: original.stringyStringo)))
        #expect(String(describing: type(of: mock.optionallyStringo)) == String(describing: type(of: original.optionallyStringo)))
        #expect(String(describing: type(of: mock.floatyNoPointy)) == String(describing: type(of: original.floatyNoPointy)))
        #expect(String(describing: type(of: mock.doublySo)) == String(describing: type(of: original.doublySo)))
        #expect(String(describing: type(of: mock.negative)) == String(describing: type(of: original.negative)))
        #expect(String(describing: type(of: mock.zero)) == String(describing: type(of: original.zero)))
        #expect(String(describing: type(of: mock.genericClass)) == String(describing: type(of: original.genericClass)))
        #expect(String(describing: type(of: mock.genericClassAs)) == String(describing: type(of: original.genericClassAs)))
        #expect(String(describing: type(of: mock.array)) == String(describing: type(of: original.array)))
        #expect(String(describing: type(of: mock.boolNo)) == String(describing: type(of: original.boolNo)))
        #expect(String(describing: type(of: mock.boolYes)) == String(describing: type(of: original.boolYes)))
        #expect(String(describing: type(of: mock.boolMaybeYes)) == String(describing: type(of: original.boolMaybeYes)))
        #expect(String(describing: type(of: mock.largeInty)) == String(describing: type(of: original.largeInty)))
    }

    @Test
    func convenienceMatcherAmbiguity() {
        let mock = MockConvenienceMatchersAmbiguer()
        stub(mock) { stub in
            when(stub.a(a: [1])).thenReturn(false)
            when(stub.a(a: ["gg"])).thenReturn(false)
            when(stub.a(a: [false])).thenReturn(false)
            when(stub.a(a: "gg")).thenReturn(false)

            when(stub.a(a: [1: true])).then { $0[1] ?? false }
            when(stub.a(a: [1: true, 2: false])).then { _ in true }
            when(stub.a(a: Set([true, true, false]))).thenReturn(false)
        }

        #expect(!mock.a(a: [1]))
        #expect(!mock.a(a: ["gg"]))
        #expect(!mock.a(a: [false]))

        #expect(mock.a(a: [1: true]))
        #expect(mock.a(a: [1: true, 2: false]))
        #expect(mock.a(a: [2: false, 1: true]))

        #expect(!mock.a(a: Set([true, true, false])))
        #expect(!mock.a(a: Set([false, true, true])))

        verify(mock).a(a: [1])
        verify(mock).a(a: ["gg"])
        verify(mock).a(a: [false])

        verify(mock, times(3)).a(a: any(Dictionary<Int, Bool>.self))

        verify(mock, times(2)).a(a: any(Set<Bool>.self))
    }
}
