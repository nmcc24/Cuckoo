protocol Loader {
    nonisolated(nonsending) func load() async -> Int
    @concurrent func compute() async -> Int
}
