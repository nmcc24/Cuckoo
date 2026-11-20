// Deprecated requirements of a protocol with an associated type, which the mock's type eraser forwards to the
// default implementation. Swift 6.4's `@diagnose` says the deprecation isn't the eraser's to warn about; Swift 6.3
// has no way to, so its mocks keep the warning (expected-failures-swift-6.3.txt).
protocol LegacyFeed {
    associatedtype Item
    @available(*, deprecated, message: "use next()")
    func old() -> Item
    func next() -> Item
    @available(*, deprecated)
    var legacyCount: Int { get }
}
