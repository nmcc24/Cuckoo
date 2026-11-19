import Testing
import Cuckoo
@testable import CuckooMocks
@testable import CuckooTestSources

/// A class's member that writes `Self` or an associated type as a concrete type is the one the mock overrides, so a
/// call through the protocol reaches the stub.
struct ConcreteWitnessTests {
    @Test
    func aMemberGivingAnAssociatedTypeIsMockedForItsRequirement() {
        let mock = MockConcreteWitnessMaker()
        stub(mock) { stub in
            when(stub.make()).thenReturn(42)
        }

        #expect(produced(by: mock) == 42)
        verify(mock).make()
    }

    @Test
    func aMemberTakingItsOwnTypeIsMockedForASelfRequirement() {
        let mock = MockConcreteWitnessComparer()
        stub(mock) { stub in
            when(stub.isSame(as: any())).thenReturn(true)
        }

        #expect(areSame(mock, mock))
        verify(mock).isSame(as: any())
    }
}
