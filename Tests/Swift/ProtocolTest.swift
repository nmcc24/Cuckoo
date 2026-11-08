import Testing
import Cuckoo
@testable import CuckooMocks
@testable import CuckooTestSources

struct ProtocolTest {

    private let mock = MockTestedProtocol()

    @Test
    func readOnlyProperty() {
        stub(mock) { mock in
            when(mock.readOnlyProperty.get).thenReturn("a")
        }

        #expect(mock.readOnlyProperty == "a")
        verify(mock).readOnlyProperty.get()
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
    func throwingProperty() throws {
        stub(mock) { mock in
            when(mock.throwsProperty.get).thenReturn(5)
        }

        #expect(try mock.throwsProperty == 5)
        verify(mock).throwsProperty.get()

        clearInvocations(mock)

        stub(mock) { mock in
            when(mock.throwsProperty.get).thenThrow(TestError.unknown)
        }

        #expect(throws: TestError.self) { try mock.throwsProperty }

        verify(mock).throwsProperty.get()
    }

    @Test
    func asyncProperty() async {
        stub(mock) { mock in
            when(mock.asyncProperty.get).thenReturn(5)
        }

        let result = await mock.asyncProperty
        #expect(result == 5)
        verify(mock).asyncProperty.get()
    }

    @Test
    func asyncThrowingProperty() async {
        stub(mock) { mock in
            when(mock.asyncThrowsProperty.get).thenReturn(5)
        }

        let result = try! await mock.asyncThrowsProperty
        #expect(result == 5)
        verify(mock).asyncThrowsProperty.get()

        clearInvocations(mock)

        stub(mock) { mock in
            when(mock.asyncThrowsProperty.get).thenThrow(TestError.unknown)
        }

        var threw = false
        do {
            _ = try await mock.asyncThrowsProperty
        } catch {
            threw = true
        }

        #expect(threw)
        verify(mock).asyncThrowsProperty.get()
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
        stub(mock) { mock in
            when(mock.withClosure(anyClosure())).then { $0("a") }
        }

        #expect(mock.withClosure { _ in 1 } == 1)
        verify(mock).withClosure(anyClosure())
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
    func withImplicitlyUnwrappedOptional() {
        stub(mock) { mock in
            when(mock.withImplicitlyUnwrappedOptional(i: anyInt())).thenReturn("test")
        }

        #expect(mock.withImplicitlyUnwrappedOptional(i: 5) == "test")
        verify(mock).withImplicitlyUnwrappedOptional(i: equal(to: 5))
    }

    @Test
    func emptyLabels() {
        let mock = MockEmptyLabelProtocol<Bool>()
        stub(mock) { mock in
            when(mock.empty(anyString())).thenReturn(420)
            when(mock.empty(anyString())).then { print("OK: \($0)") }
            when(mock.empty(any())).thenReturn(true)
        }

        #expect(mock.empty("hello there") == 420)
        mock.empty("here") as Void
        #expect(mock.empty(false))

        // the calls are ambiguous if we do not specify the input and output types
        _ = verify(mock).empty(anyString()) as __DoNotUse<String, Int>
        _ = verify(mock).empty(anyString()) as __DoNotUse<String, Void>
        _ = verify(mock).empty(any()) as __DoNotUse<Bool, Bool>
    }

    @Test
    func compositionalParameters() {
        let mock = MockTestedProtocol()
        stub(mock) { mock in
            when(mock.compositionalParameters(param1: any(), param2: any())).thenDoNothing()
        }
        mock.compositionalParameters(param1: 0, param2: CompositionalTest(g: "gg"))
    }

    private struct CompositionalTest: OnlyLabelProtocol, Codable {
        let g: String

        func empty(_: String) {}
        func some(some: Int) {}
        func double(here there: Bool) {}
    }

    private enum TestError: Error {
        case unknown
    }
}
