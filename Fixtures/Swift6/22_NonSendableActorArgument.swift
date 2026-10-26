// `nonisolated`, so the class stays non-Sendable under default MainActor isolation too.
nonisolated final class Box {
    var value = 0
}

protocol BoxActor: Actor {
    func take(_ box: Box) -> Int
}
