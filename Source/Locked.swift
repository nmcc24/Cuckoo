import Foundation

/// A value that is only ever read or written while holding a lock.
///
/// This is the runtime's one documented `@unchecked Sendable` box. It's sound because `withLock` is the only
/// way to reach the value. The value itself may hold non-`Sendable` things (stub actions, recorded arguments),
/// which is why the conformance can't be checked by the compiler.
///
/// It uses `NSLock` so it works on Linux and on the iOS 17 / macOS 14 floor. `Synchronization.Mutex` would
/// need iOS 18 / macOS 15.
final class Locked<Value>: @unchecked Sendable {
    private let lock = NSLock()
    private var value: Value

    init(_ value: Value) {
        self.value = value
    }

    /// Runs `body` with exclusive access to the value. `body` must not call back into code that takes the
    /// same lock, and must not run user code (matchers, stub implementations), which could.
    func withLock<Result, Failure: Error>(_ body: (inout Value) throws(Failure) -> Result) throws(Failure) -> Result {
        lock.lock()
        defer { lock.unlock() }
        return try body(&value)
    }
}
