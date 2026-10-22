protocol Networking: Sendable {
    func get(url: String, completion: @escaping @Sendable (Result<String, Error>) -> Void)
    func get(url: String) async throws -> String
}
