extension MockManager {
    /// The manager `createMock` prepared, and the type of the mock it's for.
    struct Preconfigured: Sendable {
        let manager: MockManager
        let mockType: ObjectIdentifier
        /// Whether `createMock`'s closure is still running. A task the closure starts inherits the task-local, and
        /// one that runs on after `createMock` returns must not pick up the manager.
        let isOpen = Locked(true)
    }

    /// Task-local, so a mock created in a task `createMock` didn't start never sees it.
    @TaskLocal static var preconfigured: Preconfigured?

    /// The manager `createMock` prepared for a class mock of `mockType`, if one is being created. A generated class
    /// mock picks it up as its `cuckooManager`; a protocol mock creates its own. Other mocks created inside
    /// `createMock`'s closure, such as the mock's arguments, get managers of their own.
    public static func preconfiguredManager(for mockType: Any.Type) -> MockManager? {
        guard let preconfigured, preconfigured.mockType == ObjectIdentifier(mockType),
              preconfigured.isOpen.withLock({ $0 }) else {
            return nil
        }
        return preconfigured.manager
    }
}
