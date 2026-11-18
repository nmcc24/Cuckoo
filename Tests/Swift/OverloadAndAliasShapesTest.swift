import Testing
import Cuckoo
@testable import CuckooMocks
@testable import CuckooTestSources

struct OverloadAndAliasShapesTests {
    /// `Self.ID` is the mock's copy of the typealias, and `Self.Callback` a closure the mock records.
    @Test
    func aTypealiasNamedThroughSelfIsStubbedAndVerified() {
        let mock = MockAliasedLookup()
        stub(mock) { stub in
            when(stub.find(1)).thenReturn(2)
            when(stub.each(any())).then { callback in callback(3) }
        }

        var seen: [Int] = []
        mock.each { seen.append($0) }
        #expect(mock.find(1) == 2)
        #expect(seen == [3])
        verify(mock).find(1)
        verify(mock).each(any())
    }

    /// A typealias isn't `Self`: the member forwards to a default implementation.
    @Test
    func aMemberNamingATypealiasThroughSelfForwardsToTheDefaultImplementation() {
        let mock = MockAliasedLookup()
        mock.enableDefaultImplementation(AliasedLookupImplementation())

        var seen: [Int] = []
        mock.each { seen.append($0) }
        #expect(mock.find(1) == 2)
        #expect(seen == [7])
    }

    /// The type eraser's setters take function values spelled through a typealias, and an implicitly unwrapped one.
    @Test
    func theTypeEraserSetsFunctionAndImplicitlyUnwrappedValues() {
        let implementation = ObservedStoreImplementation()
        let mock = MockObservedStore<String>()
        mock.enableDefaultImplementation(implementation)

        mock.handler = { $0 * 2 }
        #expect(implementation.handler(2) == 4)
        #expect(mock.handler(3) == 6)

        mock[0] = { $0 + 1 }
        #expect(implementation.handler(2) == 3)
        #expect(mock[0](3) == 4)

        #expect(mock.implicit == nil)
        mock.implicit = "set"
        #expect(implementation.implicit == "set")
        #expect(mock.implicit == "set")
    }

    /// A call picks the overload as Swift does: the sync one in a synchronous context, the async one with `await`.
    @Test
    func aSyncAndAnAsyncOverloadAreStubbedAndVerifiedApart() async {
        let mock = MockOverloadedLoader()
        stub(mock) { stub in
            when(stub.value()).thenReturn(1)
        }
        when(await mock.cuckooStubbingProxy().value()).thenReturn(2)

        let synchronous = { mock.value() }()
        let asynchronous = await mock.value()
        #expect(synchronous == 1)
        #expect(asynchronous == 2)

        await verify(mock).value()
        inOrder {
            verify(mock).value()
        }
        verifyNoMoreInteractions(mock)
    }

    /// Stubbing one overload leaves the other unstubbed.
    @Test
    func stubbingTheSyncOverloadLeavesTheAsyncOneUnstubbed() async {
        let mock = MockOverloadedLoader()
        stub(mock) { stub in
            when(stub.value()).thenReturn(1)
        }

        await withKnownIssue {
            _ = await mock.value()
        } matching: { issue in
            issue.description.contains("No stub for value()")
        }
    }

    /// The mock overrides what it can, and leaves the `final` and `static` members that implement the protocol's
    /// requirements to the class.
    @Test
    func aClassesFinalAndStaticWitnessesAreNotMocked() {
        let mock = MockFinalWitnessCounter()
        stub(mock) { stub in
            when(stub.decrement()).thenReturn(5)
        }

        #expect(mock.decrement() == 5)
        #expect(mock.increment() == 1)
        MockFinalWitnessCounter.reset()
        verify(mock).decrement()
        verifyNoMoreInteractions(mock)
    }
}
