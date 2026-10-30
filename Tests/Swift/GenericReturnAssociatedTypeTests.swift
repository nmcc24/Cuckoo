import Testing
import Cuckoo
@testable import CuckooMocks
@testable import CuckooTestSources

private struct DescribingLabeler: Labeler {
    func label<T>(_ value: T) -> String { "\(value)" }
    func labels<T>(_ values: [T]) -> [String] { values.map { "\($0)" } }
    func pair<T>(_ value: T, input: Int) -> (String, T) { ("\(input)", value) }
    func lookup<T>(_ key: T) async throws -> String? { "\(key)" == "missing" ? nil : "found \(key)" }
}

/// A generic method can't be stored as a closure, so the default implementation calls it on the opened existential,
/// and its result is cast back to the mock's `Output`.
struct GenericReturnAssociatedTypeTests {
    @Test
    func defaultImplementationReturnsTheAssociatedType() async throws {
        let mock = MockLabeler<Int, String>()
        mock.enableDefaultImplementation(DescribingLabeler())

        #expect(mock.label(42) == "42")
        #expect(mock.labels([1, 2]) == ["1", "2"])
        let pair = mock.pair(true, input: 7)
        #expect(pair.0 == "7")
        #expect(pair.1)
        #expect(try await mock.lookup("key") == "found key")
        #expect(try await mock.lookup("missing") == nil)
        verify(mock).label(equal(to: 42))
        verify(mock).pair(equal(to: true), input: equal(to: 7))
    }

    @Test
    func stubsReturnTheAssociatedType() {
        let mock = MockLabeler<Int, String>()
        stub(mock) { stub in
            when(stub.label(any(Int.self))).thenReturn("stubbed")
        }

        #expect(mock.label(1) == "stubbed")
    }
}
