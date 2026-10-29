import Testing
import Cuckoo
@testable import CuckooMocks
@testable import CuckooTestSources

/// A protocol mock stands for `Self` wherever the protocol names it: as a parameter, inside an array or an
/// optional, and as the result.
struct SelfTests {
    @Test
    func selfParametersAndResultsAreTheMock() {
        let mock = MockShape()
        let other = MockShape()
        stub(mock) { stub in
            when(stub.scaled(by: any())).thenReturn(other)
            when(stub.overlaps(any())).then { shape in shape === other }
            when(stub.union(with: any())).then { shapes in shapes.first }
        }

        #expect(mock.scaled(by: 2) === other)
        #expect(mock.overlaps(other))
        #expect(!mock.overlaps(mock))
        #expect(mock.union(with: [other, mock]) === other)
        verify(mock).scaled(by: 2)
        verify(mock, times(2)).overlaps(any())
        verify(mock).union(with: any())
    }

    @Test
    func aClassMockKeepsItsSelfResult() {
        let mock = MockPolygon()
        stub(mock) { stub in
            when(stub.duplicate()).thenCallRealImplementation()
        }

        #expect(mock.duplicate() === mock)
    }
}
