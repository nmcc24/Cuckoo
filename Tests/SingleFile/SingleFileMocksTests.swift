import Testing
import Cuckoo
@testable import CuckooSingleFileMocks
@testable import CuckooTestSources
@testable import CuckooPluginTestSources

/// `CuckooSingleFileMocks` holds every Cuckoofile module's mocks in one file, which merges the imports of all their
/// sources: a name one import declares, such as SwiftUI's `Namespace`, mustn't make a same-named source type
/// ambiguous. That it compiles is most of the test; the runtime suite covers the mocks' behaviour.
struct SingleFileMocksTests {
    @Test
    func mocksOfEveryModuleWork() {
        let greeter = MockGreeter()
        stub(greeter) { stub in
            when(stub.greet(any())).thenReturn("Hello")
        }
        let tested = MockTestedProtocol()
        stub(tested) { stub in
            when(stub.readOnlyProperty.get).thenReturn("value")
        }

        #expect(greeter.greet("Nuno") == "Hello")
        #expect(tested.readOnlyProperty == "value")
        verify(greeter).greet(equal(to: "Nuno"))
    }
}
