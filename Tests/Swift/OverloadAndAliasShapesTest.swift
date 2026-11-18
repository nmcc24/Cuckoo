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

    /// `stub.value()` and `verify(mock).value()` are the sync overload, and `async` names the async one, in the
    /// `stub` block, a plain `verify` in async code and `inOrder`.
    @Test
    func aSyncAndAnAsyncOverloadAreStubbedAndVerifiedApart() async {
        let mock = MockOverloadedLoader()
        stub(mock) { stub in
            when(stub.value()).thenReturn(1)
            when(stub.async.value()).thenReturn(2)
        }

        let synchronous = { mock.value() }()
        let asynchronous = await mock.value()
        let again = await mock.value()
        #expect(synchronous == 1)
        #expect(asynchronous == 2)
        #expect(again == 2)

        verify(mock).value()
        verify(mock, times(2)).async.value()
        inOrder {
            verify(mock).value()
            verify(mock, times(2)).async.value()
        }
        verifyNoMoreInteractions(mock)
    }

    /// `inOrder` tells the overloads apart: the async call came second.
    @Test
    func inOrderFailsWhenTheAsyncOverloadWasCalledLater() async {
        let mock = MockOverloadedLoader()
        stub(mock) { stub in
            when(stub.value()).thenReturn(1)
            when(stub.async.value()).thenReturn(2)
        }
        _ = { mock.value() }()
        _ = await mock.value()

        withKnownIssue {
            inOrder {
                verify(mock).async.value()
                verify(mock).value()
            }
        }
    }

    /// Verifying one overload doesn't count the other's calls.
    @Test
    func verifyingOneOverloadLeavesTheOthersCalls() async {
        let mock = MockOverloadedLoader()
        stub(mock) { stub in
            when(stub.async.value()).thenReturn(2)
        }
        _ = await mock.value()

        verify(mock, never()).value()
        withKnownIssue {
            verifyNoMoreInteractions(mock)
        }
        verify(mock).async.value()
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

    /// The overloads' results differ, and each proxy still tells them apart by `async`.
    @Test
    func overloadsWithDifferentResultsAreStubbedAndVerifiedApart() async {
        let mock = MockResultOverloadedLoader()
        stub(mock) { stub in
            when(stub.value()).thenReturn(1)
            when(stub.async.value()).thenReturn("async")
        }

        let synchronous: Int = mock.value()
        let asynchronous: String = await mock.value()
        #expect(synchronous == 1)
        #expect(asynchronous == "async")

        inOrder {
            verify(mock).value()
            verify(mock).async.value()
        }
        verifyNoMoreInteractions(mock)
    }

    /// The type eraser casts a typealias of the associated type between the mock's and the default
    /// implementation's, and leaves a generic parameter of the same name alone.
    @Test
    func aTypealiasOfAnAssociatedTypeForwardsToTheDefaultImplementation() {
        let mock = MockItemListing<Int>()
        mock.enableDefaultImplementation(ItemListingImplementation())

        #expect(mock.doubled([1, 2], with: "any") == [1, 2, 1, 2])
        var seen: [[Int]] = []
        mock.each("any") { seen.append($0) }
        #expect(seen == [[1, 2]])
        #expect(mock.shadowed("not items", real: [1, 2, 3]) == [3, 2, 1])
    }

    @Test
    func aTypealiasOfAnAssociatedTypeIsStubbedAndVerified() {
        let mock = MockItemListing<Int>()
        stub(mock) { stub in
            when(stub.doubled(any(), with: any(String.self))).thenReturn([7])
            when(stub.shadowed(any(String.self), real: any())).then { _, real in real }
        }

        #expect(mock.doubled([1], with: "any") == [7])
        #expect(mock.shadowed("any", real: [4]) == [4])
        verify(mock).doubled(any(), with: any(String.self))
        verify(mock).shadowed(any(String.self), real: any())
    }

    /// The requirements a superclass implements with `static` and `final` members, or in an extension, stay the
    /// superclass's for a subclass that states the protocol.
    @Test
    func aSuperclassesUnoverridableWitnessesAreNotMocked() {
        let mock = MockSuperclassWitnessChild()
        stub(mock) { stub in
            when(stub.open()).thenReturn(40)
        }

        #expect(mock.open() == 40)
        #expect(mock.ping() == 2)
        #expect(mock.hello() == 3)
        #expect(MockSuperclassWitnessChild.reset() == 1)
        verify(mock).open()
        verifyNoMoreInteractions(mock)
    }

    /// Where the mocked type has a member named `async`, `await` picks the async overload, as in a call.
    @Test
    func awaitNamesTheAsyncOverloadNextToAMemberNamedAsync() async {
        let mock = MockAsyncNamedLoader()
        stub(mock) { stub in
            when(stub.async.get).thenReturn(true)
            when(stub.value()).thenReturn(1)
        }
        when(await mock.cuckooStubbingProxy().value()).thenReturn(2)

        let synchronous = { mock.value() }()
        let asynchronous = await mock.value()
        #expect(synchronous == 1)
        #expect(asynchronous == 2)
        #expect(mock.async)

        await verify(mock).value()
        _ = { verify(mock).value() }()
        verify(mock).async.get()
        verifyNoMoreInteractions(mock)
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

    /// Members an extension of the class declares can't be overridden: the mock leaves them, and the requirements
    /// they implement, to the class.
    @Test
    func aClassesWitnessesInAnExtensionAreNotMocked() {
        let mock = MockExtensionWitnessFeed()
        stub(mock) { stub in
            when(stub.reload()).thenReturn(5)
        }

        #expect(mock.reload() == 5)
        #expect(mock.refresh() == 2)
        #expect(mock.stamp == 3)
        verify(mock).reload()
        verifyNoMoreInteractions(mock)
    }

    /// `Self.Key` next to a generic parameter `Key` is the protocol's typealias, in the mock too.
    @Test
    func aTypealiasShadowedByAGenericParameterKeepsItsType() {
        let mock = MockShadowedAliasStore()
        stub(mock) { stub in
            when(stub.key(for: 1)).thenReturn("one")
        }

        let stubbed: String = mock.key(for: 1)
        #expect(stubbed == "one")
        verify(mock).key(for: 1)

        let forwarding = MockShadowedAliasStore()
        forwarding.enableDefaultImplementation(ShadowedAliasStoreImplementation())
        #expect(forwarding.key(for: 2.5) == "2.5")
    }
}

/// A public protocol's proxies aren't `Sendable`, as an internal one's are implicitly: a test on the main actor
/// stubs and verifies both overloads without sending them anywhere.
@Suite(.cuckoo())
@MainActor
struct OverloadsOnTheMainActorTests {
    @Test
    func bothOverloadsAreStubbedAndVerifiedFromTheMainActor() async {
        let mock = MockPublicOverloadedLoader()
        stub(mock) { stub in
            when(stub.value()).thenReturn(1)
            when(stub.async.value()).thenReturn(2)
        }

        let synchronous = { mock.value() }()
        let asynchronous = await mock.value()
        #expect(synchronous == 1)
        #expect(asynchronous == 2)

        verify(mock).value()
        verify(mock).async.value()
        inOrder {
            verify(mock).value()
            verify(mock).async.value()
        }
        verifyNoMoreInteractions(mock)
    }

    /// Static overloads are stubbed in the type's `stub` block and verified the same way, `inOrder` included.
    @Test
    func staticOverloadsAreStubbedAndVerifiedFromTheMainActor() async {
        let mock = MockPublicOverloadedLoader()
        stub(MockPublicOverloadedLoader.self) { stub in
            when(stub.shared()).thenReturn(1)
            when(stub.async.shared()).thenReturn(2)
        }
        stub(mock) { stub in
            when(stub.async.value()).thenReturn(3)
        }

        let asynchronous = await MockPublicOverloadedLoader.shared()
        let synchronous = { MockPublicOverloadedLoader.shared() }()
        let value = await mock.value()
        #expect(synchronous == 1)
        #expect(asynchronous == 2)
        #expect(value == 3)

        verify(MockPublicOverloadedLoader.self).shared()
        inOrder {
            verify(MockPublicOverloadedLoader.self).async.shared()
            verify(MockPublicOverloadedLoader.self).shared()
            verify(mock).async.value()
        }
        verifyNoMoreInteractions(MockPublicOverloadedLoader.self)
    }
}
