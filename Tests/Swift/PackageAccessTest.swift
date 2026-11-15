import Testing
import Cuckoo
import CuckooMocks
import CuckooTestSources

/// A `package` type's mock is `package` too, so another module of the package can use it: this file imports the
/// mocks without `@testable`.
struct PackageAccessTest {
    @Test
    func packageProtocolIsMocked() {
        let mock = MockPackageService()
        stub(mock) { stub in
            when(stub.run(equal(to: 2))).thenReturn(4)
        }

        #expect(mock.run(2) == 4)
        verify(mock).run(equal(to: 2))
    }

    @Test
    func packageClassIsMocked() {
        let mock = MockPackageWorker()
        stub(mock) { stub in
            when(stub.work()).thenReturn("stubbed")
        }

        #expect(mock.work() == "stubbed")
        verify(mock).work()
    }

    @Test
    func publicActorProtocolIsMocked() async {
        let mock = MockPublicActorService()
        stub(mock) { stub in
            when(stub.count()).thenReturn(3)
        }

        #expect(await mock.count() == 3)
        verify(mock).count()
    }

    @Test
    func publicClassBoundProtocolsAreMocked() {
        let bound = MockPublicBoundService(id: 7)
        let plain = MockPublicPlainBoundService()
        stub(bound) { stub in
            when(stub.describe()).thenReturn("bound")
        }
        stub(plain) { stub in
            when(stub.ping()).thenReturn(true)
        }

        #expect(bound.id == 7)
        #expect(bound.describe() == "bound")
        #expect(plain.ping())
        verify(bound).describe()
        verify(plain).ping()
    }
}
