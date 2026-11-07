/// Configures a mock while ``createMock(_:configuration:)`` creates it.
public class MockBuilder {
    private let manager: MockManager

    init(manager: MockManager) {
        self.manager = manager
    }

    /// Makes the new mock call its superclass's real implementation for every unstubbed member.
    public func enableSuperclassSpy() {
        manager.enableSuperclassSpy()
    }

    /// Makes the new mock forward unstubbed calls to its default implementation, which
    /// ``Mock/enableDefaultImplementation(_:)`` sets.
    public func enableDefaultStubImplementation() {
        manager.enableDefaultStubImplementation()
    }
}
