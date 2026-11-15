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

// A parent is found as Swift finds it: through a typealias, and from an extension written with the module's name
// (the fixture matrix compiles fixtures as module Fix) or through a typealias of the type. A name that only a
// protocol nested elsewhere has means one from outside the sources, such as Swift's `Error`, not the nested one.
enum Aliased {
    protocol Service { func aliased() }
}
typealias AliasedService = Aliased.Service
protocol ThroughAlias: AliasedService { func own() }

enum Outermost {
    protocol Service { func outer() }
}
typealias OutermostAlias = Outermost
extension Fix.Outermost {
    protocol ModuleQualified: Service { func qualified() }
}
extension OutermostAlias {
    protocol AliasExtended: Service { func extended() }
}

enum Net {
    protocol Error { func netOnly() }
}
protocol Failing: Error { func fail() }

enum DescribedA { protocol CustomStringConvertible { func a() } }
enum DescribedB { protocol CustomStringConvertible { func b() } }
protocol Described: CustomStringConvertible { func other() }
extension Described {
    nonisolated var description: String { "described" }
}

// A protocol bound to a class is found by scope, so a same-named protocol elsewhere doesn't stand in for it, and
// a protocol that refines it from another scope names the class by its qualified name.
enum BoundScope {
    class Base { init() {} }
    protocol Bound: Base { func bound() }
}
enum OtherScope {
    protocol Bound { func other() }
}
protocol RefinesBound: BoundScope.Bound { func refined() }

// A `where` clause on a parent outside the sources: the mock fixes `ID == String` with a typealias, since it has
// no generic parameter to constrain, and leaves `ID: Hashable` for Swift to check on its own declarations.
protocol NamedEntity: Identifiable where ID == String {
    func name() -> String
}
extension NamedEntity {
    nonisolated var id: String { "named" }
}
protocol KeyedEntity: Identifiable where ID: Hashable {
    func key() -> Int
}
extension KeyedEntity {
    nonisolated var id: Int { 0 }
}
