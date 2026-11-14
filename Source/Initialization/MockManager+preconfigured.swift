extension MockManager {
    /// The manager `createMock` prepared, and the type of the mock it's for.
    struct Preconfigured: Sendable {
        let manager: MockManager
        let mockType: ObjectIdentifier
    }

    /// Task-local, so a mock created in another task never sees it.
    @TaskLocal static var preconfigured: Preconfigured?

    /// The manager `createMock` prepared for a mock of `mockType`, if one is being created. A generated mock picks
    /// it up as its `cuckoo_manager`. Other mocks created inside `createMock`'s closure, such as the mock's
    /// arguments, get managers of their own.
    public static func preconfiguredManager(for mockType: Any.Type) -> MockManager? {
        guard let preconfigured, preconfigured.mockType == ObjectIdentifier(mockType) else {
            return nil
        }
        return preconfigured.manager
    }
}
