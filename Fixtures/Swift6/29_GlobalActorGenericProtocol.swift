// A generic protocol isolated to a global actor: its mock forwards to a type-erased default implementation,
// which is isolated to the same actor so it can read the requirements.
@MainActor
protocol Inventory {
    associatedtype Item: Sendable
    var count: Int { get }
    var items: [Item] { get set }
    func item(at index: Int) -> Item?
    func reload() async throws
}

@globalActor
actor StorageActor {
    static let shared = StorageActor()
}

@StorageActor
protocol Ledger<Entry> {
    associatedtype Entry
    associatedtype Key: Hashable
    func entry(for key: Key) -> Entry?
    func record(_ entry: Entry, for key: Key)
}
