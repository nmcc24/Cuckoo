import Testing
@testable import Cuckoo
@testable import CuckooMocks
@testable import CuckooTestSources

/// Matching stops at the first argument a matcher rejects, as the documentation says: the matchers after it don't
/// run, so a matcher that's costly, or that only makes sense once an earlier argument matched, can rely on it.
struct ShortCircuitMatchingTest {
    @Test
    func stubSkipsTheMatchersAfterARejectedArgument() {
        let mock = MockTestedClass()
        let evaluated = Locked(0)
        let counting = ParameterMatcher<String> { _ in
            evaluated.withLock { $0 += 1 }
            return true
        }
        stub(mock) { stub in
            when(stub.withLabelAndUnderscore(labelA: anyString(), anyString())).thenDoNothing()
            when(stub.withLabelAndUnderscore(labelA: "a", counting)).thenDoNothing()
        }

        mock.withLabelAndUnderscore(labelA: "b", "x")
        #expect(evaluated.withLock { $0 } == 0)

        mock.withLabelAndUnderscore(labelA: "a", "x")
        #expect(evaluated.withLock { $0 } == 1)
    }

    @Test
    func verifySkipsTheMatchersAfterARejectedArgument() {
        let mock = MockTestedClass()
        stub(mock) { stub in
            when(stub.withLabelAndUnderscore(labelA: anyString(), anyString())).thenDoNothing()
        }
        mock.withLabelAndUnderscore(labelA: "b", "x")
        mock.withLabelAndUnderscore(labelA: "a", "y")
        let seen = Locked<[String]>([])
        let recording = ParameterMatcher<String> { value in
            seen.withLock { $0.append(value) }
            return true
        }

        verify(mock).withLabelAndUnderscore(labelA: "a", recording)

        #expect(seen.withLock { $0 } == ["y"])
    }
}
