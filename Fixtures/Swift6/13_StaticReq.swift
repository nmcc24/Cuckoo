protocol Factory {
    static func make() -> Self
    static var count: Int { get set }
    static subscript(key: String) -> Int { get }
    static func load(id: Int) async throws -> String
    func build() -> Int
}

@MainActor
protocol MainActorRegistry {
    static func current() -> String
    static var shared: Int { get }
}

protocol SendableClock: Sendable {
    static func now() -> Int
}

protocol ActorCatalog: Actor {
    static func identifier() -> String
    func items() -> [String]
}

protocol GenericFactory<Product> {
    associatedtype Product
    static func make() -> Product
    func use(_ product: Product)
}
