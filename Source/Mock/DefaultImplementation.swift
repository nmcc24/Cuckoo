/// Holds the default implementation a mock forwards to once `enableDefaultImplementation` has been called.
///
/// Generated mocks keep it in a `let`, so they need no mutable stored state of their own. That lets a mock of
/// a `Sendable` type be checked `Sendable`, and lets `enableDefaultImplementation` be `nonisolated`.
public final class DefaultImplementation<Stub>: Sendable {
    private let stub = Locked<Stub?>(nil)

    public init() {
    }

    /// The default implementation. Reading it before one was set is a programming error.
    ///
    /// The setter writes back a mutated copy, so a mutating member of a value-type default implementation
    /// (`__defaultImplStub.value.count += 1`) keeps its change, as it did when the mock stored the value itself.
    /// The member runs outside the lock.
    public var value: Stub {
        get {
            guard let stub = stub.withLock({ $0 }) else {
                fatalError("The default implementation was used before `enableDefaultImplementation` set it.")
            }
            return stub
        }
        set {
            stub.withLock { $0 = newValue }
        }
    }
}
