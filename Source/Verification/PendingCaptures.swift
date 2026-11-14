/// The captures an ``ArgumentCaptor`` made while one call's arguments were being matched. They take effect only
/// once every matcher for the call accepted it, and the stub or `verify` doing the matching took the call.
final class PendingCaptures: Sendable {
    /// The captures of the matching in progress. Without one, a captor captures at once.
    @TaskLocal static var current: PendingCaptures?

    private let captures = Locked<[() -> Void]>([])

    /// Holds back `capture` until ``commit()``.
    func add(_ capture: @escaping () -> Void) {
        captures.withLock { $0.append(capture) }
    }

    /// Makes the held-back captures take effect, in the order they were made.
    func commit() {
        let captures = captures.withLock { captures in
            defer { captures.removeAll() }
            return captures
        }
        captures.forEach { $0() }
    }

    /// Runs `matching`, holding back the captures it makes, and returns them with its result.
    static func collecting<Result>(_ matching: () -> Result) -> (Result, PendingCaptures) {
        let pending = PendingCaptures()
        let result = $current.withValue(pending) {
            matching()
        }
        return (result, pending)
    }
}
