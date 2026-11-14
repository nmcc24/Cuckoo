// Protocol shapes the generator resolves: `some` nested in a parameter type, a `nonisolated` member of a
// `@MainActor` protocol (its stubs must be `Sendable`), a qualified `@_Concurrency.MainActor`, parents found
// through enclosing scopes and through a composition typealias, and a parent declared outside the sources
// (`Identifiable`, which the mock satisfies through its class's default implementation).
protocol NestedShape {}

protocol NestedSome {
    func optional(_ value: (some NestedShape)?)
    func array(_ values: [some NestedShape])
    func tuple(_ pair: (Int, some NestedShape))
}

@MainActor
protocol MainCoordinator {
    nonisolated func identifier() -> String
    nonisolated var name: String { get }
    func start()
}

@_Concurrency.MainActor
protocol QualifiedMain {
    func load() -> Int
}

enum FeatureOne {
    protocol Service { func one() }
}

enum FeatureTwo {
    protocol Service { func two() }
    protocol Child: Service { func child() }
    protocol Qualified: FeatureOne.Service { func qualified() }
}

protocol PartA { func a() }
protocol PartB { func b() }
typealias PartAB = PartA & PartB
protocol Composed: PartAB { func composed() }

protocol Identified: Identifiable {
    func describe() -> String
}
