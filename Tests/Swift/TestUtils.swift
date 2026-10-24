@testable import Cuckoo

struct TestUtils {
    static func catchCuckooFail(inClosure closure: () -> Void) -> String? {
        let message = Locked<String?>(nil)
        var configuration = CuckooConfiguration.current
        configuration.failureHandler = { failure, _ in
            message.withLock { $0 = failure }
        }
        CuckooConfiguration.$current.withValue(configuration) {
            closure()
        }
        return message.withLock { $0 }
    }
}
