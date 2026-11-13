// A protocol that states no isolation takes its parents': Swift isolates `MainChild`'s requirements to the main
// actor through `MainParent`, makes `ActorChild` an actor protocol and `SendableChild` Sendable. The mocks and
// stubs follow, through any number of levels, and a parent's `nonisolated` member stays nonisolated.
@globalActor
actor InheritedStoreActor {
    static let shared = InheritedStoreActor()
}

@MainActor
protocol MainParent {
    var title: String { get }
    func load() -> Int
    nonisolated func identifier() -> String
}

protocol MainChild: MainParent {
    func refresh(_ count: Int)
}

protocol MainGrandchild: MainChild {
    func reset() async
}

@InheritedStoreActor
protocol StoreParent {
    func save(_ value: Int)
}

protocol StoreChild: StoreParent {
    func fetch() -> Int
}

protocol ActorParent: Actor {
    func count() -> Int
}

protocol ActorChild: ActorParent {
    func increment(by amount: Int)
}

protocol SendableParent: Sendable {
    func value() -> Int
}

protocol SendableChild: SendableParent {
    func update(_ value: Int)
}
