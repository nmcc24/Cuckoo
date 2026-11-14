// Shapes the generator must reproduce faithfully: a typed-throws getter, a `nonisolated` member of a
// `@MainActor` protocol, and a class method with default argument values.
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
