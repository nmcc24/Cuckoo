protocol Store: Actor {
    var count: Int { get }
    func increment() -> Int
    func fetch() async -> [String]
}
