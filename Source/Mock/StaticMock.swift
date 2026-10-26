/// A mock whose type has static or class members. Their stubs and calls can't live in an instance's manager,
/// so they live in the current task's ``StaticStubs`` registry, one manager per mock type.
public protocol StaticMock {
    associatedtype StaticStubbing: StubbingProxy
    associatedtype StaticVerification: VerificationProxy

    /// Whether the mocked type is a class, whose real static members can be called.
    static var cuckoo_hasSuperclass: Bool { get }
}

public extension StaticMock {
    /// The manager for this mock type's static members in the current ``StaticStubs`` scope.
    static var cuckoo_staticManager: MockManager {
        StaticStubs.manager(for: Self.self, hasParent: cuckoo_hasSuperclass)
    }
}

/// The stubs and calls of mocked static members, per mock type.
///
/// Static members have no instance to hold their stubs, and Swift Testing runs tests in parallel, so each test
/// gets a registry of its own: the `.cuckoo()` trait starts one for every test it applies to, and
/// `withStaticStubs { }` starts one for any other scope. Tasks started inside the scope see it too;
/// a `Task.detached`, a GCD queue or a notification doesn't, and its static calls fail as unstubbed.
public final class StaticStubs: Sendable {
    private let managers = Locked<[ObjectIdentifier: MockManager]>([:])

    public init() {
    }

    /// The registry for the current task, if a scope started one.
    @TaskLocal public static var current: StaticStubs?

    static func manager<M>(for type: M.Type, hasParent: Bool) -> MockManager {
        guard let registry = current else {
            reportFailure(
                "Static members of \(type) were used outside a static stubs scope. Add the `.cuckoo()` trait to the Swift Testing test or suite, or wrap the code in `withStaticStubs { }`.",
                at: (#file, #fileID, #filePath, #line, #column)
            )
            // A manager of its own, so the call fails as unstubbed instead of reaching another test's stubs.
            return MockManager(hasParent: hasParent, isStatic: true)
        }
        return registry.managers.withLock { managers in
            if let manager = managers[ObjectIdentifier(type)] {
                return manager
            }
            let manager = MockManager(hasParent: hasParent, isStatic: true)
            managers[ObjectIdentifier(type)] = manager
            return manager
        }
    }
}

/// Runs `body` with a fresh registry for static members' stubs and calls, for XCTest or any code outside a
/// Swift Testing test that has the `.cuckoo()` trait.
public func withStaticStubs<R>(_ body: () throws -> R) rethrows -> R {
    try StaticStubs.$current.withValue(StaticStubs(), operation: body)
}

/// Runs `body` with a fresh registry for static members' stubs and calls, for XCTest or any code outside a
/// Swift Testing test that has the `.cuckoo()` trait.
public nonisolated(nonsending) func withStaticStubs<R>(
    _ body: nonisolated(nonsending) () async throws -> R
) async rethrows -> R {
    try await StaticStubs.$current.withValue(StaticStubs(), operation: body)
}
