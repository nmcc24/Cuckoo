import XCTest
import Cuckoo
@testable import CuckooMocks
@testable import CuckooTestSources

/// The isolated mocks from `IsolationTests`, used from XCTest.
final class IsolationXCTest: XCTestCase {
    @MainActor
    func testMainActorProtocol() async throws {
        let mock = MockMainActorService()
        let viewModel = RecordingViewModel()
        stub(mock) { stub in
            when(stub.load(id: any())).then { id in
                viewModel.events.append("load \(id)")
                return "item \(id)"
            }
            when(stub.refresh()).thenDoNothing()
        }

        XCTAssertEqual(mock.load(id: 3), "item 3")
        try await mock.refresh()

        XCTAssertEqual(viewModel.events, ["load 3"])
        verify(mock).load(id: 3)
        verify(mock).refresh()
    }

    @MainActor
    func testMainActorClassSpy() {
        let mock = MockMainActorViewModel().withEnabledSuperclassSpy()

        XCTAssertTrue(mock.select(index: 1))
        verify(mock).select(index: 1)
    }

    func testActorProtocol() async throws {
        let mock = MockCounterStore()
        stub(mock) { stub in
            when(stub.increment(by: any())).then { _, amount in
                amount * 2
            }
            when(stub.fetch(id: any())).thenReturn("value")
        }

        let doubled = await mock.increment(by: 4)
        let fetched = try await mock.fetch(id: 9)

        XCTAssertEqual(doubled, 8)
        XCTAssertEqual(fetched, "value")
        verify(mock).increment(by: 4)
        verify(mock).fetch(id: 9)
    }
}
