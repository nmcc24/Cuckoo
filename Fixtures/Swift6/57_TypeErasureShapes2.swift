// Members of a protocol with an associated type that its mock's type eraser can't forward as written: async members
// isolated otherwise than the protocol, subscripts that are isolated, name `Self` or throw a typed error, `~Copyable`
// and `isolated` parameters, and an `inout ~Copyable` one. Each records a failure instead.
enum StoreError: Error { case failed }

struct Ticket: ~Copyable {
    var id: Int
}

protocol IsolatedAsyncStore {
    associatedtype Item
    @MainActor func onMain() async -> Item
    nonisolated(nonsending) func nonsending() async -> Item
    @concurrent func concurrent() async -> Item
    @MainActor var mainValue: Item { get async }
    func plain() -> Item
}

protocol OddSubscripts {
    associatedtype Item
    @MainActor subscript(main index: Int) -> Item { get }
    subscript(same other: Self) -> Item { get }
    subscript(typed index: Int) -> Item { get throws(StoreError) }
    subscript(plain index: Int) -> Item { get }
    @MainActor subscript(settable index: Int) -> Item { get set }
}

protocol NoncopyableArguments {
    associatedtype Item
    func borrow(_ ticket: borrowing Ticket) -> Item
    func consume(_ ticket: consuming Ticket) -> Item
    func generic<T: ~Copyable>(_ value: borrowing T) -> Item
    func update(_ ticket: inout Ticket)
    func run(isolation: isolated (any Actor)?) async -> Int
}
