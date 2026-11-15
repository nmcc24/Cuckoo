// Shapes the generator must reproduce faithfully: a typed-throws getter, a `nonisolated` member of a
// `@MainActor` protocol, a class method with default argument values, an `isolated` parameter, `nonisolated(nonsending)`
// and `@concurrent` members, and `@MainActor` members of a plain protocol.
enum ShapeFailure: Error, Equatable {
    case failed
}

protocol TypedThrowingStore {
    var value: Int { get throws(ShapeFailure) }
}

@MainActor
protocol MainActorIdentified {
    nonisolated func identifier() -> String
    func start()
}

class DefaultArgumentCounter {
    init() {}

    func count(level: Int = 1, times: Int = 2) -> Int {
        level * times
    }
}

protocol IsolatedWork {
    func run(isolation: isolated (any Actor)?) async -> Int
}

protocol NonsendingLoader {
    nonisolated(nonsending) func load() async -> Int
    @concurrent func compute() async -> Int
}

protocol MainActorMembers {
    @MainActor func track(event: String)
    @MainActor var lastEvent: String? { get }
}
