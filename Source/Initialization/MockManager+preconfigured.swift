extension MockManager {
    /// The manager `createMock` prepared for the mock being initialized. A generated mock picks it up as its
    /// `cuckoo_manager`. Task-local, so a mock created in another task never sees it.
    @TaskLocal public static var preconfiguredManager: MockManager?
}
