@available(macOS 15, iOS 18, tvOS 18, watchOS 11, *)
protocol Events {
    var stream: AsyncStream<Int> { get }
    func updates() -> any AsyncSequence<Int, Never>
}
