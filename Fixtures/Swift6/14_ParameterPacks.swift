protocol Combiner {
    func combine<each T>(_ values: repeat each T) -> (repeat each T)
    func count<each T>(_ values: repeat each T) -> Int
    func log<each T: Sendable>(prefix: String, _ values: repeat each T) async throws
    func pair<each T, each U>(_ first: repeat each T, second: repeat each U) -> (repeat each U)
}

@MainActor
protocol MainActorCombiner {
    func combine<each T>(_ values: repeat each T) -> (repeat each T)
}

// An actor mock's `then` closure gets the pack from the manager: a closure that built it from the captured
// parameters would send a non-Sendable value into the actor-isolated closure.
protocol ActorCombiner: Actor {
    func count<each T>(_ values: repeat each T) -> Int
    func combine<each T>(_ values: repeat each T) -> (repeat each T)
    func combineAsync<each T>(_ values: repeat each T) async throws -> (repeat each T)
}

