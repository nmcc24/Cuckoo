// A member with an `isolated` parameter in a `@MainActor` protocol, returning a non-`Sendable` value: the member is
// isolated to its parameter, not to the main actor.
final class Report {}

@MainActor
protocol Reporter {
    func make(isolation: isolated (any Actor)?) async -> Report
    func count() -> Int
}
