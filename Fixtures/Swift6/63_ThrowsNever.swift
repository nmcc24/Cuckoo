// `throws(Never)` doesn't throw: the mock leaves it out, which also avoids a Swift 6.3 compiler crash.
protocol NeverFailing {
    func run() throws(Never) -> Int
    func load() async throws(Swift.Never) -> String
    var value: Int { get throws(Never) }
}

class NeverFailingService {
    init() {}
    func run() throws(Never) -> Int { 0 }
}
