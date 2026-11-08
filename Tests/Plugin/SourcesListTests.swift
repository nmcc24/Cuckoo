import Testing
import Cuckoo
@testable import CuckooMocks
@testable import CuckooPluginTestSources

/// `CuckooPluginTestSources` has a Cuckoofile entry without `sources`, so its mocks come from the files
/// `CuckooPluginModular` lists for the target.
struct SourcesListTests {
    @Test
    func pluginListedFilesAreMocked() {
        let mock = MockGreeter()
        stub(mock) { stub in
            when(stub.greet(equal(to: "Ada"))).thenReturn("Hello, Ada")
        }

        #expect(mock.greet("Ada") == "Hello, Ada")
        verify(mock).greet(equal(to: "Ada"))
    }
}
