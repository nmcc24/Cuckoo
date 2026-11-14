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
}
#endif
