// A member with an `isolated` parameter in a `@MainActor` protocol, returning a non-`Sendable` value: the member is
// isolated to its parameter, not to the main actor.
final class Report {}

@MainActor
protocol Reporter {
    func make(isolation: isolated (any Actor)?) async -> Report
    func count() -> Int
}

// The same in an `Actor` protocol, whose member also runs on the actor its parameter names, not on the mock.
protocol ReportingActor: Actor {
    func make(isolation: isolated (any Actor)?) async -> Report
    func count(isolation: isolated (any Actor)?) async -> Int
}

// `Optional` parameters written with a specifier, in a `Sendable` protocol, matched by their wrapped type.
protocol Forwarding: Sendable {
    func send(_ report: sending Report?)
    func update(_ value: inout Int?)
}
