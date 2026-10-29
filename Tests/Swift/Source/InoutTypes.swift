protocol Counter {
    func increment(_ value: inout Int)
    func rename(_ name: inout String, suffix: String) -> Int
    func adjust(_ value: inout Int, by delta: Int) async throws -> Bool
}

protocol InoutCounterStore: Actor {
    func bump(_ value: inout Int, by delta: Int)
}

class CounterClass {
    init() {}

    func double(_ value: inout Int) {
        value *= 2
    }
}
