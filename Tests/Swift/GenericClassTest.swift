import Foundation
import Testing
import Cuckoo
@testable import CuckooMocks
@testable import CuckooTestSources

extension GenericClass: Mocked {
    typealias MockType = MockGenericClass<T, U, V>
}

struct GenericClassTest {
    private let mock: MockGenericClass<Int, String, Bool> = MockGenericClass(theT: 10, theU: "Hello, generics!", theV: false)
    private let original: GenericClass<Int, String, Bool> = GenericClass(theT: 42, theU: "Hello world!", theV: false)

    @Test
    func readWritePropertyWithMockCreator() {
        let mock = createMock(for: GenericClass<Int, String, Bool>.self) { builder, stub in
            when(stub.readWritePropertyU.get).thenReturn("a")

            return MockGenericClass(theT: 0, theU: "", theV: true)
        }

        #expect(mock.readWritePropertyU == "a")
        verify(mock).readWritePropertyU.get()
    }

    @Test
    func readWriteProperty() {
        stub(mock) { mock in
            when(mock.readWritePropertyV.get).thenReturn(true)
        }

        #expect(mock.readWritePropertyV == true)
        verify(mock).readWritePropertyV.get()
    }

    @Test
    func constantProperty() {
        mock.enableDefaultImplementation(original)
        #expect(mock.constant == 10.0)
    }

    @Test
    func modification() {
        mock.enableDefaultImplementation(original)
        let numbers = [127, 0, 0, 1]
        for number in numbers {
            original.readWritePropertyT = number
            #expect(mock.readWritePropertyT == number)
        }

        verify(mock, times(numbers.count)).readWritePropertyT.get()
    }

    @Test
    func readWriteProperties() {
        var calledT = false
        var calledU = false
        var calledV = false
        stub(mock) { mock in
            when(mock.readWritePropertyT.get).thenReturn(1)
            when(mock.readWritePropertyT.set(anyInt())).then { _ in calledT = true }

            when(mock.readWritePropertyU.get).thenReturn("Hello, mocker!")
            when(mock.readWritePropertyU.set(anyString())).then { _ in calledU = true }

            when(mock.readWritePropertyV.get).thenReturn(false)
            when(mock.readWritePropertyV.set(any())).then { _ in calledV = true }
        }

        mock.readWritePropertyT = 0
        #expect(mock.readWritePropertyT == 1)
        #expect(calledT)
        verify(mock).readWritePropertyT.get()
        verify(mock).readWritePropertyT.set(0)

        mock.readWritePropertyU = "NO MOCKING FOR YOU"
        #expect(mock.readWritePropertyU == "Hello, mocker!")
        #expect(calledU)
        verify(mock).readWritePropertyU.get()
        verify(mock).readWritePropertyU.set("NO MOCKING FOR YOU")

        mock.readWritePropertyV = true
        #expect(mock.readWritePropertyV == false)
        #expect(calledV)
        verify(mock).readWritePropertyV.get()
        verify(mock).readWritePropertyV.set(true)
    }

    @Test
    func optionalProperty() {
        var called = false
        stub(mock) { mock in
            when(mock.optionalProperty.get).thenReturn(nil)
            when(mock.optionalProperty.set(anyString())).then { _ in called = true }
        }

        mock.optionalProperty = "tukabel"

        #expect(mock.optionalProperty == nil)
        #expect(called)
        verify(mock).optionalProperty.get()
        verify(mock).optionalProperty.set(equal(to: "tukabel"))
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
    func unequal() {
        stub(mock) { mock in
            when(mock.unequal(one: false, two: false)).thenReturn(false)
            when(mock.unequal(one: false, two: true)).thenReturn(true)
            when(mock.unequal(one: true, two: false)).thenReturn(true)
            when(mock.unequal(one: true, two: true)).thenReturn(false)
        }

        #expect(!mock.unequal(one: false, two: false))
        #expect(mock.unequal(one: false, two: true))
        #expect(mock.unequal(one: true, two: false))
        #expect(!mock.unequal(one: true, two: true))
    }

    @Test
    func getThird() {
        stub(mock) { mock in
            when(mock.getThird(foo: anyInt(), bar: "gimme true", baz: any())).thenReturn(false)
            when(mock.getThird(foo: anyInt(), bar: "gimme false", baz: any())).thenReturn(true)
        }

        #expect(!mock.getThird(foo: 10, bar: "gimme true", baz: true))
        verify(mock).getThird(foo: 10, bar: "gimme true", baz: true)
        #expect(mock.getThird(foo: 1099, bar: "gimme false", baz: false))
        verify(mock).getThird(foo: 1099, bar: "gimme false", baz: false)
    }

    @Test
    func testPrint() {
        stub(mock) { mock in
            when(mock.print(theT: anyInt())).thenDoNothing()
        }

        mock.print(theT: 555)
        verify(mock).print(theT: 555)
    }

    @Test
    func encode() throws {
        mock.enableDefaultImplementation(original)
        stub(mock) { mock in
            when(mock.encode(theU: anyString())).thenCallRealImplementation()
        }

        let world = "Hello, world!"
        let expected = try JSONEncoder().encode(["root": world])
        #expect(mock.encode(theU: world) == expected)
        verify(mock).encode(theU: world)
    }

    @Test
    func withClosure() {
        stub(mock) { mock in
            when(mock.withClosure(anyClosure())).then { $0(666) }
        }

        #expect(mock.withClosure { number in number * 2 + 5 } == 1337)
        verify(mock).withClosure(anyClosure())
    }

    @Test
    func withGenericClosure() {
        stub(mock) { mock in
            when(mock.genericClosure(gg: "gg", closure: anyClosure())).thenDoNothing()
        }

        mock.genericClosure(gg: "gg", closure: { print($0.readWritePropertyT) })
        verify(mock).genericClosure(gg: "gg", closure: anyClosure())
    }

    @Test
    func compositeGenericParameter() {
        stub(mock) { mock in
            when(mock.genericMethodParameterComposite(g: any())).thenDoNothing()
        }

        mock.genericMethodParameterComposite(g: Namespace.Custom())
        verify(mock).genericMethodParameterComposite(g: any())
    }
}
