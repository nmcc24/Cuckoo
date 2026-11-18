import Testing
import Cuckoo
@testable import CuckooMocks
@testable import CuckooTestSources

/// What Matching.md says about values as matchers, where a plain value doesn't compile.
struct ValueMatchingTest {
    private let mock = MockValueMatching()

    init() {
        stub(mock) { stub in
            when(stub.scale(by: any())).thenDoNothing()
            when(stub.tag(any())).thenDoNothing()
        }
    }

    /// A literal has its default type: `1.5` is a `Double`, which a `Float` parameter doesn't take.
    @Test
    func aFloatParameterTakesATypedValue() {
        mock.scale(by: 1.5)

        verify(mock).scale(by: Float(1.5))
        verify(mock).scale(by: equal(to: 1.5))
    }

    /// The collections are value matchers only for a parameter that isn't optional.
    @Test
    func anOptionalCollectionTakesEqualTo() {
        mock.tag(["a"])
        mock.tag(nil)

        verify(mock).tag(equal(to: ["a"]))
        verify(mock).tag(isNil())
        verify(mock, never()).tag(equal(to: ["b"]))
    }
}
