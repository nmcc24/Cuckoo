import Testing
import Cuckoo
@testable import CuckooMocks
@testable import CuckooTestSources

/// A protocol that requires a superclass gets a mock that subclasses it. The class's own members keep their
/// real implementation.
struct ClassBoundProtocolTests {
    @Test
    func mockSubclassesTheRequiredClass() {
        let mock = MockWidgetModel(id: 7)
        stub(mock) { stub in
            when(stub.refresh()).thenReturn(3)
        }

        let widget: Widget = mock
        #expect(mock.refresh() == 3)
        #expect(widget.render() == "widget 7")
        verify(mock).refresh()
    }

    @Test
    func whereSelfBindsTheSuperclassThroughOtherProtocols() {
        let mock = MockTitledWidgetScreen(id: 2)
        stub(mock) { stub in
            when(stub.title()).thenReturn("Title")
            when(stub.subtitle()).thenReturn("Subtitle")
        }

        #expect(mock.title() == "Title")
        #expect(mock.subtitle() == "Subtitle")
        #expect(mock.id == 2)
        verify(mock).title()
        verify(mock).subtitle()
    }

    @Test
    func anyObjectProtocolsKeepIdentity() {
        let mock = MockWidgetDelegate()
        stub(mock) { stub in
            when(stub.widgetDidLoad(id: any())).thenDoNothing()
        }
        let delegate: any WidgetDelegate = mock

        delegate.widgetDidLoad(id: 4)

        #expect(delegate === mock)
        verify(mock).widgetDidLoad(id: 4)
    }
}

/// Generic initializers are mocked like any other initializer.
struct GenericInitTests {
    @Test
    func classMockForwardsAGenericInitializer() {
        let mock = MockGenericInitBox(value: 42)
        stub(mock) { stub in
            when(stub.describe()).thenCallRealImplementation()
        }

        #expect(mock.describe() == "42")
    }

    @Test
    func protocolMockHasTheGenericInitializer() {
        let mock = MockGenericInitFactory(value: "anything")
        stub(mock) { stub in
            when(stub.describe()).thenReturn("stubbed")
        }

        #expect(mock.describe() == "stubbed")
        verify(mock).describe()
    }
}
