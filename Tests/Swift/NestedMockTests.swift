import Testing
import Cuckoo
@testable import CuckooMocks
@testable import CuckooTestSources

extension Nested.NestedExtensionTestedClass: Mocked {
    typealias CuckooMockType = Nested.MockNestedExtensionTestedClass
}

/// Mocks of classes nested in other types and extensions. `NestedClassTest` runs the whole `TestedClass` suite on
/// one of them; the generated code of the others differs only in the names, which the runtime snapshot covers, so
/// each gets one test of stubbing, a property, a call to the real implementation and a default implementation.
struct NestedMockTests {
    @Test
    func createMockOfANestedClass() {
        let mock = createMock(for: Nested.NestedExtensionTestedClass.self) { _, stub in
            when(stub.readOnlyProperty.get).thenReturn("a")
            return Nested.MockNestedExtensionTestedClass()
        }

        #expect(mock.readOnlyProperty == "a")
        verify(mock).readOnlyProperty.get()
    }

    @Test
    func nestedInAnExtension() {
        let mock = Nested.MockNestedExtensionTestedClass()
        stub(mock) { stub in
            when(stub.readWriteProperty.get).thenReturn(10)
            when(stub.callingCountCharactersMethodWithHello()).thenCallRealImplementation()
            when(stub.count(characters: any())).thenReturn(2)
        }

        #expect(mock.readWriteProperty == 10)
        #expect(mock.callingCountCharactersMethodWithHello() == 2)
        verify(mock).readWriteProperty.get()
        verify(mock).count(characters: "Hello")

        let defaults = Nested.MockNestedExtensionTestedClass()
        defaults.enableDefaultImplementation(Nested.NestedExtensionTestedClassStub())
        #expect(defaults.callingCountCharactersMethodWithHello() == 0)
        verify(defaults).callingCountCharactersMethodWithHello()
    }

    @Test
    func nestedInAStructExtension() {
        let mock = NestedStruct.MockNestedExtensionTestedClass()
        stub(mock) { stub in
            when(stub.readWriteProperty.get).thenReturn(10)
            when(stub.callingCountCharactersMethodWithHello()).thenCallRealImplementation()
            when(stub.count(characters: any())).thenReturn(2)
        }

        #expect(mock.readWriteProperty == 10)
        #expect(mock.callingCountCharactersMethodWithHello() == 2)
        verify(mock).readWriteProperty.get()
        verify(mock).count(characters: "Hello")

        let defaults = NestedStruct.MockNestedExtensionTestedClass()
        defaults.enableDefaultImplementation(NestedStruct.NestedExtensionTestedClassStub())
        #expect(defaults.callingCountCharactersMethodWithHello() == 0)
        verify(defaults).callingCountCharactersMethodWithHello()
    }

    @Test
    func subclassNestedInAStruct() {
        let mock = NestedStruct.MockNestedTestedSubclass()
        stub(mock) { stub in
            when(stub.readWriteProperty.get).thenReturn(10)
            when(stub.callingCountCharactersMethodWithHello()).thenCallRealImplementation()
            when(stub.count(characters: any())).thenReturn(2)
        }

        #expect(mock.readWriteProperty == 10)
        #expect(mock.callingCountCharactersMethodWithHello() == 2)
        verify(mock).readWriteProperty.get()
        verify(mock).count(characters: "Hello")

        let defaults = NestedStruct.MockNestedTestedSubclass()
        defaults.enableDefaultImplementation(NestedStruct.NestedTestedSubclassStub())
        #expect(defaults.callingCountCharactersMethodWithHello() == 0)
        verify(defaults).callingCountCharactersMethodWithHello()
    }

    @Test
    func subclassNestedInAClass() {
        let mock = Nested.MockNestedTestedSubclass()
        stub(mock) { stub in
            when(stub.readWriteProperty.get).thenReturn(10)
            when(stub.callingCountCharactersMethodWithHello()).thenCallRealImplementation()
            when(stub.count(characters: any())).thenReturn(2)
        }

        #expect(mock.readWriteProperty == 10)
        #expect(mock.callingCountCharactersMethodWithHello() == 2)
        verify(mock).readWriteProperty.get()
        verify(mock).count(characters: "Hello")

        let defaults = Nested.MockNestedTestedSubclass()
        defaults.enableDefaultImplementation(Nested.NestedTestedSubclassStub())
        #expect(defaults.callingCountCharactersMethodWithHello() == 0)
        verify(defaults).callingCountCharactersMethodWithHello()
    }

    @Test
    func subclassNestedTwice() {
        let mock = Multi.Nested.MockMultiNestedTestedSubclass()
        stub(mock) { stub in
            when(stub.readWriteProperty.get).thenReturn(10)
            when(stub.callingCountCharactersMethodWithHello()).thenCallRealImplementation()
            when(stub.count(characters: any())).thenReturn(2)
        }

        #expect(mock.readWriteProperty == 10)
        #expect(mock.callingCountCharactersMethodWithHello() == 2)
        verify(mock).readWriteProperty.get()
        verify(mock).count(characters: "Hello")

        let defaults = Multi.Nested.MockMultiNestedTestedSubclass()
        defaults.enableDefaultImplementation(Multi.Nested.MultiNestedTestedSubclassStub())
        #expect(defaults.callingCountCharactersMethodWithHello() == 0)
        verify(defaults).callingCountCharactersMethodWithHello()
    }

    @Test
    func nestedTwiceInAnExtension() {
        let mock = Multi.Nested.MockNestedExtensionTestedClass()
        stub(mock) { stub in
            when(stub.readWriteProperty.get).thenReturn(10)
            when(stub.callingCountCharactersMethodWithHello()).thenCallRealImplementation()
            when(stub.count(characters: any())).thenReturn(2)
        }

        #expect(mock.readWriteProperty == 10)
        #expect(mock.callingCountCharactersMethodWithHello() == 2)
        verify(mock).readWriteProperty.get()
        verify(mock).count(characters: "Hello")

        let defaults = Multi.Nested.MockNestedExtensionTestedClass()
        defaults.enableDefaultImplementation(Multi.Nested.NestedExtensionTestedClassStub())
        #expect(defaults.callingCountCharactersMethodWithHello() == 0)
        verify(defaults).callingCountCharactersMethodWithHello()
    }

    @Test
    func subclassNestedThreeLevelsDeep() {
        let mock = Multi.Layered.Nested.MockMultiLayeredNestedTestedSubclass()
        stub(mock) { stub in
            when(stub.readWriteProperty.get).thenReturn(10)
            when(stub.callingCountCharactersMethodWithHello()).thenCallRealImplementation()
            when(stub.count(characters: any())).thenReturn(2)
        }

        #expect(mock.readWriteProperty == 10)
        #expect(mock.callingCountCharactersMethodWithHello() == 2)
        verify(mock).readWriteProperty.get()
        verify(mock).count(characters: "Hello")

        let defaults = Multi.Layered.Nested.MockMultiLayeredNestedTestedSubclass()
        defaults.enableDefaultImplementation(Multi.Layered.Nested.MultiLayeredNestedTestedSubclassStub())
        #expect(defaults.callingCountCharactersMethodWithHello() == 0)
        verify(defaults).callingCountCharactersMethodWithHello()
    }
}
