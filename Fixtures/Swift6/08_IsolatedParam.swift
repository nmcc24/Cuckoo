protocol IsolatedWork {
    func run(isolation: isolated (any Actor)?) async -> Int
}
