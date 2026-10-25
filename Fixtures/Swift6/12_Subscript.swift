protocol Cache {
    subscript(key: String) -> Int? { get set }
}

protocol Grid {
    subscript(row row: Int, column column: Int) -> Double { get set }
    subscript(remote key: String) -> String { get async throws }
    subscript<T: Equatable>(echo value: T) -> T { get }
}

@MainActor
protocol MainActorTable {
    subscript(index: Int) -> String { get set }
}

protocol SendableLookup: Sendable {
    subscript(key: String) -> Int { get }
}

protocol ActorStore: Actor {
    subscript(key: String) -> Int { get }
}
