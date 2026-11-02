import Testing
import Cuckoo
@testable import CuckooMocks
@testable import CuckooPluginTestSources

/// `CuckooPluginTestSources` has a Cuckoofile entry without `sources`, so its mocks come from the files
/// `CuckooPluginModular` lists for the target. SwiftPM only: the Tuist project runs the generator without a plugin.
struct SourcesListTests {
    @Test
    func pluginListedFilesAreMocked() {
        let mock = MockGreeter()
        stub(mock) { stub in
            when(stub.greet(equal(to: "Nuno"))).thenReturn("Hello, Nuno")
        }

        #expect(mock.greet("Nuno") == "Hello, Nuno")
        verify(mock).greet(equal(to: "Nuno"))
    }
}
