import Testing
@testable import Cuckoo

struct TestUtils {
    /// The failure `closure` reports, if any, without failing the test. A second failure fails the test, so that
    /// one the test doesn't expect isn't hidden behind the one it checks.
    static func catchCuckooFail(
        sourceLocation: Testing.SourceLocation = #_sourceLocation,
        inClosure closure: () -> Void
    ) -> String? {
        let messages = Locked<[String]>([])
        var configuration = CuckooConfiguration.current
        configuration.failureHandler = { failure in
            messages.withLock { $0.append(failure.message) }
        }
        CuckooConfiguration.$current.withValue(configuration) {
            closure()
        }
        let caught = messages.withLock { $0 }
        if caught.count > 1 {
            Issue.record("Expected one Cuckoo failure, got \(caught.count):\n\(caught.joined(separator: "\n"))", sourceLocation: sourceLocation)
        }
        return caught.first
    }
}
