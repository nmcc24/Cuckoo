@MainActor
protocol Coordinator {
    nonisolated func identifier() -> String
    func start()
}
