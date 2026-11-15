import Testing
import Cuckoo
@testable import CuckooMocks
@testable import CuckooTestSources

/// A `then` closure gets a non-escaping closure written with a specifier and can call it during the call.
struct ClosureSpecifierTests {
    @Test
    func protocolMockCallsTheClosures() {
        let mock = MockClosureSpecifierService()
        stub(mock) { stub in
            when(stub.run(any())).then { operation in operation() }
            when(stub.read(any())).then { operation in operation() + 1 }
            when(stub.aliased(any())).then { operation in operation() }
            when(stub.swap(any())).then { operation in operation = {} }
        }

        var runs = 0
        mock.run { runs += 1 }
        mock.aliased { runs += 1 }
        let value = mock.read { 41 }
        var operation: () -> Void = { runs += 100 }
        mock.swap(&operation)
        operation()

        #expect(runs == 2)
        #expect(value == 42)
        verify(mock).run(any())
        verify(mock).read(any())
        verify(mock).aliased(any())
        verify(mock).swap(any())
    }

    @Test
    func classSpyRunsTheOriginal() {
        let mock = MockClosureSpecifierRunner().withEnabledSuperclassSpy()

        var runs = 0
        mock.run { runs += 1 }
        mock.aliased { runs += 1 }

        #expect(runs == 2)
        #expect(mock.read { 7 } == 7)
        verify(mock).run(any())
        verify(mock).aliased(any())
        verify(mock).read(any())
    }
}
