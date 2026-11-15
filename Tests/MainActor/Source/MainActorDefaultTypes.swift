// Types of a module built with `.defaultIsolation(MainActor.self)`: those that state no isolation are
// `@MainActor`, and their mocks, generated with `defaultIsolation = "MainActor"`, must be too.

protocol DefaultIsolatedGreeter {
    var name: String { get }
    func greet(_ person: String) -> String
}

class DefaultIsolatedCounter {
    // Declared, not implicit: a subclass of a class relying on its implicit `init()` doesn't compile under MainActor
    // default isolation (a Swift issue, fixture 50).
    init() {}

    func increment(by amount: Int) -> Int {
        amount
    }
}

nonisolated protocol NonisolatedClock: Sendable {
    func now() -> Int
}
