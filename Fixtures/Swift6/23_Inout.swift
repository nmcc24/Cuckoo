protocol Accumulator {
    func add(_ total: inout Int)
    func append(_ text: inout String, _ suffix: String, count: inout Int) -> Bool
    func load(_ buffer: inout [UInt8]) async throws -> Int
    func parse(_ cursor: inout Int) throws(ParseError) -> String
    static func reset(_ value: inout Int)
}

struct ParseError: Error {}

protocol AccumulatorActor: Actor {
    func add(_ total: inout Int, step: Int)
    func load(_ buffer: inout [UInt8]) async -> Int
}

@MainActor
protocol MainActorAccumulator {
    func add(_ total: inout Int)
}

class Doubler {
    init() {}
    func double(_ value: inout Int) { value *= 2 }
    func apply(_ value: inout Int, _ transform: (Int) -> Int) { value = transform(value) }
}
