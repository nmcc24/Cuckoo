import Testing
import Cuckoo
@testable import CuckooMocks
@testable import CuckooTestSources

struct NestedClassTest {

    private let mock = Nested.MockNestedTestedClass()

    @Test
    func readOnlyPropertyWithMockCreator() {
        let mock = createMock(Nested.MockNestedTestedClass.self) { builder, stub in
            when(stub.readOnlyProperty.get).thenReturn("a")

            return Nested.MockNestedTestedClass()
        }

        #expect(mock.readOnlyProperty == "a")
        verify(mock).readOnlyProperty.get()
    }

    @Test
    func readOnlyProperty() {
        let mock = Nested.MockNestedTestedClass()

        stub(mock) { mock in
            when(mock.readOnlyProperty.get).thenReturn("a")
        }

        #expect(mock.readOnlyProperty == "a")
        verify(mock).readOnlyProperty.get()
    }

    @Test
    func readOnlyOptionalProperty() {
        let mock = Nested.MockNestedTestedClass()

        stub(mock) { mock in
            when(mock.readOnlyOptionalProperty.get).thenReturn("a")
        }

        #expect(mock.readOnlyOptionalProperty == "a")
        verify(mock).readOnlyOptionalProperty.get()
    }

    @Test
    func optionalReadOnlyPropertyIsNil() {
        let mock = Nested.MockNestedTestedClass()

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
            when(mock.readWriteProperty.set(any())).then { _ in called = true }
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
            when(mock.optionalProperty.set(any())).then { _ in called = true }
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
            when(mock.withClosure(any())).then { $0("a") }
            when(mock.withClosureReturningVoid(any())).then { $0("a")() }
            when(mock.withClosureReturningInt(any())).then { $0("a")(1) }
            when(mock.withOptionalClosureAlone(any())).then { $0?("a")(1) ?? 1 }
            when(mock.withNestedClosure1(any())).then { $0("a")({ Int($0) ?? 1 }) }
            when(mock.withNestedClosure2(any())).then { $0({ Int($0) ?? 1 })({ Int($0) ?? 1 }) }
        }

        #expect(mock.withClosure { _ in 1 } == 1)
        #expect(mock.withClosureReturningVoid {_ in { return 1 } } == 1)
        #expect(mock.withClosureReturningInt { _ in { _ in return 1 } } == 1)
        #expect(mock.withOptionalClosureAlone { _ in { _ in return 1 } } == 1)
        #expect(mock.withNestedClosure1 { _ in { _ in return 1 } } == 1)
        #expect(mock.withNestedClosure2 { _ in { _ in return 1 } } == 1)

        verify(mock).withClosure(any())
        verify(mock).withClosureReturningVoid(any())
        verify(mock).withClosureReturningInt(any())
        verify(mock).withOptionalClosureAlone(any())
        verify(mock).withNestedClosure1(any())
        verify(mock).withNestedClosure2(any())
    }

    @Test
    func withEscape() {
        var called = false
        stub(mock) { mock in
            when(mock.withEscape(any(), action: any())).then { text, closure in closure(text) }
        }

        mock.withEscape("a") { called = $0 == "a" }

        #expect(called)
        verify(mock).withEscape(any(), action: any())
    }

    @Test
    func withOptionalClosure() {
        var called = false
        stub(mock) { mock in
            when(mock.withOptionalClosure(any(), closure: any())).then { text, closure in closure?(text)  }
        }

        mock.withOptionalClosure("a") { called = $0 == "a" }

        #expect(called)
        verify(mock).withOptionalClosure(any(), closure: any())
    }

    @Test
    func withLabel() {
        var called = false
        stub(mock) { mock in
            when(mock.withLabelAndUnderscore(labelA: any(), any())).then { _ in called = true }
        }

        mock.withLabelAndUnderscore(labelA: "a", "b")
        #expect(called)
        verify(mock).withLabelAndUnderscore(labelA: any(), any())
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
        mock.enableDefaultImplementation(Nested.NestedTestedClassStub())

        #expect(mock.callingCountCharactersMethodWithHello() == 0)
        verify(mock).callingCountCharactersMethodWithHello()
    }
}
