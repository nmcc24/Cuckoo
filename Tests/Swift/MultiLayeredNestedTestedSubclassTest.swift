import Foundation
import Testing
import Cuckoo
@testable import CuckooMocks
@testable import CuckooTestSources

struct MultiLayeredNestedTestedSubclassTest {

    private let mock = Multi.Layered.Nested.MockMultiLayeredNestedTestedSubclass()

    @Test
    func readOnlyProperty() {
        let mock = Multi.Layered.Nested.MockMultiLayeredNestedTestedSubclass()

        stub(mock) { mock in
            when(mock.readOnlyProperty.get).thenReturn("a")
        }

        #expect(mock.readOnlyProperty == "a")
        verify(mock).readOnlyProperty.get()
    }

    @Test
    func readOnlyOptionalProperty() {
        let mock = Multi.Layered.Nested.MockMultiLayeredNestedTestedSubclass()

        stub(mock) { mock in
            when(mock.readOnlyOptionalProperty.get).thenReturn("a")
        }

        #expect(mock.readOnlyOptionalProperty == "a")
        verify(mock).readOnlyOptionalProperty.get()
    }

    @Test
    func optionalReadOnlyPropertyIsNil() {
        let mock = Multi.Layered.Nested.MockMultiLayeredNestedTestedSubclass()

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
            when(mock.withClosureReturningVoid(anyClosure())).then { $0("a")() }
            when(mock.withClosureReturningInt(anyClosure())).then { $0("a")(1) }
            when(mock.withOptionalClosureAlone(anyClosure())).then { $0?("a")(1) ?? 1 }
            when(mock.withNestedClosure1(anyClosure())).then { $0("a")({ Int($0) ?? 1 }) }
            when(mock.withNestedClosure2(anyNestedClosure())).then { $0({ Int($0) ?? 1 })({ Int($0) ?? 1 }) }
        }

        #expect(mock.withClosure { _ in 1 } == 1)
        #expect(mock.withClosureReturningVoid {_ in { return 1 } } == 1)
        #expect(mock.withClosureReturningInt { _ in { _ in return 1 } } == 1)
        #expect(mock.withOptionalClosureAlone { _ in { _ in return 1 } } == 1)
        #expect(mock.withNestedClosure1 { _ in { _ in return 1 } } == 1)
        #expect(mock.withNestedClosure2 { _ in { _ in return 1 } } == 1)

        verify(mock).withClosure(anyClosure())
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
        mock.enableDefaultImplementation(Multi.Layered.Nested.MultiLayeredNestedTestedSubclassStub())

        #expect(mock.callingCountCharactersMethodWithHello() == 0)
        verify(mock).callingCountCharactersMethodWithHello()
    }
}
