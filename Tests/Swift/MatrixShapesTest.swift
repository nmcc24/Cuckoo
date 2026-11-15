import Testing
import Cuckoo
@testable import CuckooMocks
@testable import CuckooTestSources

/// The shapes the fixture matrix only compiles, stubbed, called and verified.
struct MatrixShapesTest {
    /// An `AsyncSequence` existential and an `AsyncStream` property return what their stubs give.
    @Test
    func asyncSequenceMembersReturnTheirStubs() async {
        guard #available(macOS 15, iOS 18, tvOS 18, watchOS 11, *) else { return }
        let mock = MockEventFeed()
        stub(mock) { stub in
            when(stub.stream.get).then { AsyncStream { $0.yield(1); $0.finish() } }
            when(stub.updates()).then { AsyncStream { $0.yield(2); $0.yield(3); $0.finish() } }
        }

        var streamed: [Int] = []
        for await value in mock.stream {
            streamed.append(value)
        }
        var updates: [Int] = []
        for await value in mock.updates() {
            updates.append(value)
        }
        #expect(streamed == [1])
        #expect(updates == [2, 3])
        verify(mock).stream.get()
        verify(mock).updates()
    }

    /// A method with a value generic parameter is stubbed and verified for the count its argument has, and the
    /// superclass spy runs the real one.
    @Test
    func valueGenericMembersAreStubbedAndVerified() {
        guard #available(macOS 26, iOS 26, tvOS 26, watchOS 26, *) else { return }
        let mock = MockInlineBuffer<4>()
        stub(mock) { stub in
            when(stub.first(any(InlineArray<2, Int>.self))).thenReturn(42)
        }

        let pair: InlineArray<2, Int> = [7, 8]
        #expect(mock.first(pair) == 42)
        verify(mock).first(any(InlineArray<2, Int>.self))

        let spy = MockInlineBuffer<4>().withEnabledSuperclassSpy()
        let triple: InlineArray<3, Int> = [5, 6, 7]
        #expect(spy.first(triple) == 5)
    }

    /// The members inside `#if DEBUG` are mocked in the same condition, so a debug build stubs them.
    @Test
    func membersInsideIfDebugAreMocked() {
        let mock = MockDebugReporting()
        stub(mock) { stub in
            #if DEBUG
            when(stub.debugInfo.get).thenReturn("debug")
            #else
            when(stub.releaseInfo.get).thenReturn("release")
            #endif
            when(stub.report()).thenReturn("report")
        }

        #if DEBUG
        #expect(mock.debugInfo == "debug")
        #else
        #expect(mock.releaseInfo == "release")
        #endif
        #expect(mock.report() == "report")
    }

    #if compiler(>=6.4)
    /// The type eraser forwards a deprecated requirement to the default implementation, as any other.
    @Test
    @diagnose(DeprecatedDeclaration, as: ignored)
    func deprecatedRequirementsForwardToTheDefaultImplementation() {
        let mock = MockLegacySource<Int>()
        mock.enableDefaultImplementation(LegacyCounter())

        // Called outside `#expect`, whose expansion `@diagnose` doesn't reach.
        let old = mock.old()
        #expect(old == 1)
        #expect(mock.next() == 2)
        verify(mock).old()
        verify(mock).next()
    }
    #endif
}
