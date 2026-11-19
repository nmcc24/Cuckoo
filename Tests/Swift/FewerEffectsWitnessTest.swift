import Testing
import Cuckoo
@testable import CuckooMocks
@testable import CuckooTestSources

/// The mock overrides the class's member that implements a requirement with fewer effects, so a call through the
/// protocol reaches the stub.
struct FewerEffectsWitnessTests {
    @Test
    func aMemberWithFewerEffectsIsMockedForItsRequirement() async throws {
        let mock = MockFewerEffectsLoader()
        stub(mock) { stub in
            when(stub.load()).thenReturn(1)
            when(stub.later()).thenReturn(2)
        }

        let loading: any FewerEffectsLoading = mock
        #expect(try loading.load() == 1)
        #expect(await loading.later() == 2)
        verify(mock).load()
        verify(mock).later()
    }

    @Test
    func aTypedThrowIsMockedForAnUntypedRequirement() throws {
        let mock = MockTypedFewerEffectsLoader()
        stub(mock) { stub in
            when(stub.load()).thenThrow(FewerEffectsError.failed)
        }

        let loading: any TypedFewerEffectsLoading = mock
        #expect(throws: FewerEffectsError.failed) { try loading.load() }
        verify(mock).load()
    }
}
