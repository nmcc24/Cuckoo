import Testing
@testable import Cuckoo
@testable import CuckooMocks
@testable import CuckooTestSources

/// An unstubbed call returning a protocol the module mocks records its failure and answers with a new `…Stub` of
/// the protocol, so the test goes on.
struct StubDefaultTest {
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

    private struct NamedPart: Part {
        let name: String

        func weight() -> Int { 1 }
    }

    @Test
    func anUnstubbedCallReturnsTheProtocolsStub() {
        let log = FailureLog()
        let mock = MockAssembly()

        CuckooConfiguration.$current.withValue(log.configuration) {
            let spare = mock.spare()
            #expect(spare is PartStub)
            // The stub does nothing and returns default values.
            #expect(spare.name == "" && spare.weight() == 0)
            #expect(mock.part is PartStub)
            // Each call gets a new one.
            #expect(mock.spare() as AnyObject !== spare as AnyObject)
        }
        #expect(log.all.count == 3)
        #expect(log.all.first?.hasPrefix("No stub for spare().") == true)
        verify(mock, times(2)).spare()
    }

    @Test
    func asyncMembersAndClassMocksReturnItToo() async {
        let log = FailureLog()
        let mock = MockAssembly()
        let workbench = MockWorkbench()

        await CuckooConfiguration.$current.withValue(log.configuration) {
            #expect(await mock.fetched() is PartStub)
            #expect(workbench.part() is PartStub)
        }
        #expect(log.all.count == 2)
    }

    /// The stub of a `@MainActor` protocol is created wherever the mock is called.
    @Test
    func aMainActorProtocolsStubIsCreatedOffTheMainActor() async {
        let log = FailureLog()
        let mock = MockAssembly()

        let gauge = CuckooConfiguration.$current.withValue(log.configuration) {
            mock.gauge()
        }
        #expect(gauge is GaugeStub)
        #expect(await gauge.reading() == 0)
        #expect(log.all.count == 1)
    }

    @Test
    func optionalsAndArraysKeepTheirOwnDefaults() {
        let log = FailureLog()
        let mock = MockAssembly()

        CuckooConfiguration.$current.withValue(log.configuration) {
            #expect(mock.optionalPart() == nil)
            #expect(mock.parts().isEmpty)
        }
        #expect(log.all.count == 2)
    }

    /// A throwing member has a way to say it isn't stubbed, so it doesn't answer with a stub.
    @Test
    func aThrowingMemberStillThrows() {
        let log = FailureLog()
        let mock = MockAssembly()

        CuckooConfiguration.$current.withValue(log.configuration) {
            #expect(throws: CuckooError.unstubbedCall(method: "checked() throws -> any Part")) {
                try mock.checked()
            }
        }
        #expect(log.all.count == 1)
    }

    @Test
    func aRegisteredDefaultWinsOverTheStub() {
        let log = FailureLog()
        let mock = MockAssembly()
        var configuration = log.configuration
        configuration.defaultValues.register(for: (any Part).self) { NamedPart(name: "registered") }

        CuckooConfiguration.$current.withValue(configuration) {
            #expect(mock.spare().name == "registered")
            #expect(mock.part.name == "registered")
        }
        #expect(log.all.count == 2)
    }

    @Test(.cuckoo(defaultValues: {
        var values = DefaultValues()
        values.register(for: (any Part).self) { NamedPart(name: "trait") }
        return values
    }()))
    func aDefaultFromTheTraitWinsToo() {
        let log = FailureLog()
        let mock = MockAssembly()

        CuckooConfiguration.$current.withValue(log.configuration) {
            #expect(mock.spare().name == "trait")
        }
        #expect(log.all.count == 1)
    }

    @Test
    func aStubbedCallReturnsItsStubbedValue() {
        let mock = MockAssembly()
        stub(mock) { stub in
            when(stub.spare()).thenReturn(NamedPart(name: "stubbed"))
        }

        #expect(mock.spare().name == "stubbed")
    }

    /// A generated stub's own members answer the same way, so a stub an unstubbed call returned can be used further.
    @Test
    func aStubsMembersReturnStubsToo() {
        let assembly = AssemblyStub()
        #expect(assembly.spare() is PartStub)
        #expect(assembly.part is PartStub)
        #expect(assembly.optionalPart() == nil)
        #expect(WorkbenchStub().part() is PartStub)

        var configuration = CuckooConfiguration.current
        configuration.defaultValues.register(for: (any Part).self) { NamedPart(name: "registered") }
        CuckooConfiguration.$current.withValue(configuration) {
            #expect(assembly.spare().name == "registered")
        }
    }
}
