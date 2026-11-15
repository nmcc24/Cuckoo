@testable import Cuckoo

struct TestUtils {
    static func catchCuckooFail(inClosure closure: () -> Void) -> String? {
        let message = Locked<String?>(nil)
        var configuration = CuckooConfiguration.current
        configuration.failureHandler = { failure in
            message.withLock { $0 = failure.message }
        }
        CuckooConfiguration.$current.withValue(configuration) {
            closure()
        }
        return message.withLock { $0 }
    }
}
