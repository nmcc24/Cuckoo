// `nonisolated`, so the class stays non-Sendable under default MainActor isolation too.
nonisolated final class Box {
    var value = 0
}

// Each member's `invoke` closure captures a non-Sendable argument and hands it to the `then` closure, on the
// actor (Swift 6.2 rejected the capture; 6.3 is the minimum). The async member would also forward it to a
// default implementation, another actor, which no Swift version allows; actor mocks have none.
protocol BoxActor: Actor {
    var current: Box { get set }

    func take(_ box: Box) -> Int
    func swap(_ first: Box, _ second: Box) throws -> Box
    func load(_ box: Box) async -> Int
    subscript(box: Box) -> Int { get }
}
