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
        #expect(String(decoding: result.standardErrorContent, as: UTF8.self).contains("Enabling superclass spy is not allowed after the mock's first stub or call"))
    }

    /// A stub sets the mock up too: the spy can't come after it.
    @Test
    func superclassSpyAfterTheFirstStubStopsTheProcess() async throws {
        let result = try #require(await #expect(processExitsWith: .failure, observing: [\.standardErrorContent]) {
            let late = MockTestedClass()
            stub(late) { stub in
                when(stub.noReturn()).thenDoNothing()
            }
            late.enableSuperclassSpy()
        })
        #expect(String(decoding: result.standardErrorContent, as: UTF8.self).contains("Enabling superclass spy is not allowed after the mock's first stub or call"))
    }

    /// `reset` clears a mock's stubs and calls, but doesn't make it new: the spy still can't be enabled.
    @Test
    func superclassSpyAfterResetStopsTheProcess() async throws {
        let result = try #require(await #expect(processExitsWith: .failure, observing: [\.standardErrorContent]) {
            let late = MockTestedClass()
            stub(late) { stub in
                when(stub.noReturn()).thenDoNothing()
            }
            late.noReturn()
            reset(late)
            late.enableSuperclassSpy()
        })
        #expect(String(decoding: result.standardErrorContent, as: UTF8.self).contains("Enabling superclass spy is not allowed after the mock's first stub or call"))
    }

    /// `clearInvocations` doesn't make a mock new either: the default implementation still can't be enabled.
    @Test
    func defaultImplementationAfterClearInvocationsStopsTheProcess() async throws {
        let result = try #require(await #expect(processExitsWith: .failure, observing: [\.standardErrorContent]) {
            let late = MockTestedProtocol()
            _ = late.count(characters: "a")
            clearInvocations(late)
            late.enableDefaultImplementation(TestedProtocolStub())
        })
        #expect(String(decoding: result.standardErrorContent, as: UTF8.self).contains("Enabling the default implementation is not allowed after the mock's first stub or call"))
    }

    /// Nor can the default implementation be replaced once the mock is in use.
    @Test
    func replacingTheDefaultImplementationAfterTheFirstCallStopsTheProcess() async throws {
        let result = try #require(await #expect(processExitsWith: .failure, observing: [\.standardErrorContent]) {
            let late = MockTestedProtocol()
            late.enableDefaultImplementation(TestedProtocolStub())
            _ = late.count(characters: "a")
            late.enableDefaultImplementation(TestedProtocolStub())
        })
        #expect(String(decoding: result.standardErrorContent, as: UTF8.self).contains("Enabling the default implementation is not allowed after the mock's first stub or call"))
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

    /// A non-escaping closure can't outlive its call, so a `verify` gets a stand-in for it, which says so when called.
    @Test
    func callingANonEscapingClosureAVerifyCapturedStopsTheProcess() async throws {
        let result = try #require(await #expect(processExitsWith: .failure, observing: [\.standardErrorContent]) {
            let mock = MockTestedClass()
            stub(mock) { stub in
                when(stub.withClosure(any())).thenReturn(0)
            }
            _ = mock.withClosure { _ in 1 }
            let closure = ArgumentCaptor<(String) -> Int>()
            verify(mock).withClosure(closure.capture())
            _ = closure.value?("a")
        })
        #expect(String(decoding: result.standardErrorContent, as: UTF8.self).contains("A non-escaping closure can't be called after the call it was passed to"))
    }

    /// A member returning `Self` can't reach the default implementation, and the mock's type has no default value.
    @Test
    func defaultImplementationOfAMemberReturningSelfStopsTheProcess() async throws {
        let result = try #require(await #expect(processExitsWith: .failure, observing: [\.standardErrorContent]) {
            let mock = MockShape()
            mock.enableDefaultImplementation(ShapeStub())
            _ = mock.scaled(by: 2)
        })
        #expect(String(decoding: result.standardErrorContent, as: UTF8.self).contains("has no default value"))
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
        #expect(String(decoding: result.standardErrorContent, as: UTF8.self).contains("Enabling the default implementation is not allowed after the mock's first stub or call"))
    }

}
#endif
