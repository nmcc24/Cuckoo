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
    func unstubbedCallWithNoDefaultValueStopsTheProcess() async {
        await #expect(processExitsWith: .failure) {
            // `Data` has no registered default, so the call has nothing to return.
            _ = MockGenericClass<Int, String, Bool>(theT: 0, theU: "", theV: false).encode(theU: "")
        }
    }

    @Test
    func superclassSpyAfterTheFirstCallStopsTheProcess() async {
        await #expect(processExitsWith: .failure) {
            let late = MockTestedClass()
            stub(late) { stub in
                when(stub.noReturn()).thenDoNothing()
            }
            late.noReturn()
            late.enableSuperclassSpy()
        }
    }

    @Test
    func defaultValueOfAnUnregisteredTypeStopsTheProcess() async {
        await #expect(processExitsWith: .failure) {
            _ = DefaultValueRegistry.defaultValue(for: Data.self)
        }
    }

    @Test
    func typedThrowsStubThrowingAnotherErrorStopsTheProcess() async {
        await #expect(processExitsWith: .failure) {
            let mock = MockClassWithTypedThrows()
            stub(mock) { stub in
                when(stub.typedThrows()).then { throw StubError() }
            }
            _ = try? mock.typedThrows()
        }
    }
}
#endif
