protocol Events {
    var stream: AsyncStream<Int> { get }
    func updates() -> any AsyncSequence<Int, Never>
}
