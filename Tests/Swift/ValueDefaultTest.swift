import Testing
@testable import Cuckoo
@testable import CuckooMocks
@testable import CuckooTestSources

/// An unstubbed call returning one of the sources' own structs or enums records its failure and answers with a
/// value the mock builds: `Type()`, or an enum's first case without associated values.
struct ValueDefaultTest {
    /// Collects the failures reported in its scope, so a test can check them without failing.
    private final class FailureLog: Sendable {
        private let messages = Locked<[String]>([])

        var all: [String] {
            messages.withLock { $0 }
        }

        /// The current configuration, reporting its failures here.
        var configuration: CuckooConfiguration {
            var configuration = CuckooConfiguration.current
            configuration.failureHandler = { failure in self.messages.withLock { $0.append(failure.message) } }
            return configuration
        }
    }

    @Test
    func anUnstubbedCallReturnsAValueFromTheInitializer() {
        let log = FailureLog()
        let mock = MockConsole()

        CuckooConfiguration.$current.withValue(log.configuration) {
            #expect(mock.preferences == Preferences(volume: 5, label: nil))
        }
        #expect(log.all.count == 1)
        #expect(log.all.first?.hasPrefix("No stub for the getter of preferences.") == true)
        verify(mock).preferences.get()
    }

    @Test
    func anEnumIsItsFirstCaseWithoutAssociatedValues() async {
        let log = FailureLog()
        let mock = MockConsole()

        await CuckooConfiguration.$current.withValue(log.configuration) {
            #expect(mock.heading() == .north)
            #expect(await mock.progress() == .idle)
        }
        #expect(log.all.count == 2)
    }

    @Test
    func aClassMockReturnsThemToo() {
        let log = FailureLog()
        let mock = MockCabinet()

        CuckooConfiguration.$current.withValue(log.configuration) {
            #expect(mock.preferences() == Preferences())
            #expect(mock.heading() == .north)
        }
        #expect(log.all.count == 2)
    }

    @Test
    func optionalsAndArraysKeepTheirOwnDefaults() {
        let log = FailureLog()
        let mock = MockConsole()

        CuckooConfiguration.$current.withValue(log.configuration) {
            #expect(mock.optionalPreferences() == nil)
            #expect(mock.headings().isEmpty)
        }
        #expect(log.all.count == 2)
    }

    @Test
    func aRegisteredDefaultWinsOverTheGeneratedValue() {
        let log = FailureLog()
        let mock = MockConsole()
        var configuration = log.configuration
        configuration.defaultValues.register(Preferences(volume: 9, label: "registered"))
        configuration.defaultValues.register(Heading.south)

        CuckooConfiguration.$current.withValue(configuration) {
            #expect(mock.preferences == Preferences(volume: 9, label: "registered"))
            #expect(mock.heading() == .south)
        }
        #expect(log.all.count == 2)
    }

    @Test(.cuckoo(defaultValues: {
        var values = DefaultValues()
        values.register(Heading.south)
        return values
    }()))
    func aDefaultFromTheTraitWinsToo() {
        let log = FailureLog()
        let mock = MockConsole()

        CuckooConfiguration.$current.withValue(log.configuration) {
            #expect(mock.heading() == .south)
        }
        #expect(log.all.count == 1)
    }

    @Test
    func aStubbedCallReturnsItsStubbedValue() {
        let mock = MockConsole()
        stub(mock) { stub in
            when(stub.heading()).thenReturn(.south)
        }

        #expect(mock.heading() == .south)
    }

    /// A member the mock can't forward to its default implementation, here for taking `Self`, records the failure
    /// and answers with the same value.
    @Test
    func anUnforwardableMemberReturnsItToo() {
        let log = FailureLog()
        let mock = MockDial()
        mock.enableDefaultImplementation(DialStub())

        CuckooConfiguration.$current.withValue(log.configuration) {
            #expect(mock.heading(relativeTo: mock) == .north)
        }
        #expect(log.all.count == 1)
        #expect(log.all.first?.contains("can't forward") == true)
    }

    /// A generated stub's own members answer the same way.
    @Test
    func aStubsMembersReturnTheValuesToo() async {
        let console = ConsoleStub()
        #expect(console.preferences == Preferences())
        #expect(console.heading() == .north)
        #expect(await console.progress() == .idle)
        #expect(CabinetStub().heading() == .north)

        var configuration = CuckooConfiguration.current
        configuration.defaultValues.register(Heading.south)
        CuckooConfiguration.$current.withValue(configuration) {
            #expect(console.heading() == .south)
        }
    }
}
