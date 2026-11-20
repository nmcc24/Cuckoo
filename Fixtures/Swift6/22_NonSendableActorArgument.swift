// `nonisolated`, so the class stays non-Sendable under default MainActor isolation too.
nonisolated final class Box {
    var value = 0
}

// Each member hands a non-Sendable argument to its `then` closure, which the manager passes in rather than
// letting the closure capture it: Swift 6.2 rejected the capture, and 6.3 and 6.4 still reject it for a `sending`
// parameter or a parameter pack (fixtures 07, 14 and 61). The async member would also forward the argument to a
// default implementation, another actor, which no Swift version allows; actor mocks have none.
protocol BoxActor: Actor {
    var current: Box { get set }

    func take(_ box: Box) -> Int
    func swap(_ first: Box, _ second: Box) throws -> Box
    func load(_ box: Box) async -> Int
    subscript(box: Box) -> Int { get }
}
