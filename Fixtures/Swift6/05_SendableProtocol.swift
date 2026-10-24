protocol Networking: Sendable {
    func get(url: String, completion: @escaping @Sendable (Result<String, Error>) -> Void)
    func get(url: String) async throws -> String
}

// A generic Sendable protocol: its mock forwards to a type-erased default implementation,
// which must be Sendable too.
protocol KeyValueStore: Sendable {
    associatedtype Key: Hashable & Sendable
    var count: Int { get }
    func value(for key: Key) -> String?
}
