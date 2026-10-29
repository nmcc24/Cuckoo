import Testing
import Cuckoo
@testable import CuckooMocks
@testable import CuckooTestSources

/// A protocol's mock takes the associated types it inherits as generic parameters, unless the protocol fixes them.
struct InheritedAssociatedTypeTests {
    @Test
    func inheritedAssociatedTypesBecomeGenericParameters() {
        let mock = MockCachingStore<String, Int>()
        stub(mock) { stub in
            when(stub.value(for: "a")).thenReturn(1)
            when(stub.cachedKeys()).thenReturn(["a"])
        }

        #expect(mock.value(for: "a") == 1)
        #expect(mock.cachedKeys() == ["a"])
        verify(mock).value(for: "a")
        verify(mock).cachedKeys()
    }

    @Test
    func aFixedAssociatedTypeIsATypealias() {
        let mock = MockNamedStore<Int>()
        stub(mock) { stub in
            when(stub.value(for: 1)).thenReturn("one")
            when(stub.names()).thenReturn(["one"])
        }

        #expect(mock.value(for: 1) == "one")
        #expect(mock.names() == ["one"])
    }

    @Test
    func aParentsPrimaryAssociatedTypeCanBeFixed() {
        let mock = MockIntFeed()
        stub(mock) { stub in
            when(stub.latest()).thenReturn(3)
            when(stub.total()).thenReturn(6)
        }

        #expect(mock.latest() == 3)
        #expect(mock.total() == 6)
        verify(mock).total()
    }
}
