import Foundation
import Testing
@testable import Cuckoo
@testable import CuckooMocks
@testable import CuckooTestSources

// Exit tests run their body in a child process, which Swift Testing supports on macOS and Linux, not on the iOS,
// tvOS or watchOS simulators.
#if os(macOS) || os(Linux)
/// The calls that can't be answered, and the misuses that would leave a mock in a state no test means, record a
/// failure and then stop the process.
struct CrashTest {
    @Test
    func unstubbedCallWithNoDefaultValueStopsTheProcess() async throws {
        let result = try #require(await #expect(processExitsWith: .failure, observing: [\.standardErrorContent]) {
            // `Data` has no registered default, so the call has nothing to return.
            _ = MockGenericClass<Int, String, Bool>(theT: 0, theU: "", theV: false).encode(theU: "")
        })
        #expect(String(decoding: result.standardErrorContent, as: UTF8.self).contains("has no default value. Stub it"))
    }

    @Test
    func superclassSpyAfterTheFirstCallStopsTheProcess() async throws {
        let result = try #require(await #expect(processExitsWith: .failure, observing: [\.standardErrorContent]) {
            let late = MockTestedClass()
            stub(late) { stub in
                when(stub.noReturn()).thenDoNothing()
            }
            late.noReturn()
            late.enableSuperclassSpy()
        })
        #expect(String(decoding: result.standardErrorContent, as: UTF8.self).contains("Enabling superclass spy is not allowed after the mock's first call"))
    }

    @Test
    func defaultValueOfAnUnregisteredTypeStopsTheProcess() async throws {
        let result = try #require(await #expect(processExitsWith: .failure, observing: [\.standardErrorContent]) {
            _ = DefaultValueRegistry.defaultValue(for: Data.self)
        })
        #expect(String(decoding: result.standardErrorContent, as: UTF8.self).contains("does not have default return value registered"))
    }

    @Test
    func typedThrowsStubThrowingAnotherErrorStopsTheProcess() async throws {
        let result = try #require(await #expect(processExitsWith: .failure, observing: [\.standardErrorContent]) {
            let mock = MockClassWithTypedThrows()
            stub(mock) { stub in
                when(stub.typedThrows()).then { throw StubError() }
            }
            _ = try? mock.typedThrows()
        })
        #expect(String(decoding: result.standardErrorContent, as: UTF8.self).contains("which isn't a"))
    }

    @Test
    func defaultImplementationOfAMemberWithSelfStopsTheProcess() async throws {
        let result = try #require(await #expect(processExitsWith: .failure, observing: [\.standardErrorContent]) {
            let mock = MockShape()
            mock.enableDefaultImplementation(ShapeStub())
            _ = mock.scaled(by: 2)
        })
        #expect(String(decoding: result.standardErrorContent, as: UTF8.self).contains("because it takes or returns Self"))
    }

    @Test
    func superclassSpyOfAVariadicMemberStopsTheProcess() async throws {
        let result = try #require(await #expect(processExitsWith: .failure, observing: [\.standardErrorContent]) {
            let mock = MockVariadicFormatter()
            mock.enableSuperclassSpy()
            _ = mock.join("a", "b", separator: "-")
        })
        #expect(String(decoding: result.standardErrorContent, as: UTF8.self).contains("because it takes a variadic argument"))
    }

    @Test
    func superclassSpyOfANoncopyableArgumentStopsTheProcess() async throws {
        let result = try #require(await #expect(processExitsWith: .failure, observing: [\.standardErrorContent]) {
            let mock = MockTicketShredder()
            mock.enableSuperclassSpy()
            _ = mock.shred(Ticket(seat: 1))
        })
        #expect(String(decoding: result.standardErrorContent, as: UTF8.self).contains("because it takes a ~Copyable argument"))
    }

    @Test
    func superclassSpyWithTheDefaultImplementationEnabledStopsTheProcess() async throws {
        let result = try #require(await #expect(processExitsWith: .failure, observing: [\.standardErrorContent]) {
            let mock = MockTestedClass()
            mock.enableDefaultImplementation(TestedClassStub())
            mock.enableSuperclassSpy()
        })
        #expect(String(decoding: result.standardErrorContent, as: UTF8.self).contains("not allowed with the default implementation enabled"))
    }

    @Test
    func defaultImplementationWithTheSuperclassSpyEnabledStopsTheProcess() async throws {
        let result = try #require(await #expect(processExitsWith: .failure, observing: [\.standardErrorContent]) {
            let mock = MockTestedClass()
            mock.enableSuperclassSpy()
            mock.enableDefaultImplementation(TestedClassStub())
        })
        #expect(String(decoding: result.standardErrorContent, as: UTF8.self).contains("not allowed with superclass spy enabled"))
    }

    @Test
    func defaultImplementationAfterTheFirstCallStopsTheProcess() async throws {
        let result = try #require(await #expect(processExitsWith: .failure, observing: [\.standardErrorContent]) {
            let mock = MockTestedProtocol()
            stub(mock) { stub in
                when(stub.noReturn()).thenDoNothing()
            }
            mock.noReturn()
            mock.enableDefaultImplementation(TestedProtocolStub())
        })
        #expect(String(decoding: result.standardErrorContent, as: UTF8.self).contains("Enabling the default implementation is not allowed after the mock's first call"))
    }

}
#endif
