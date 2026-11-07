/// A mocked type that names its generated mock, so ``createMock(for:configuration:)`` can find it.
public protocol Mocked {
    /// The generated mock of this type.
    associatedtype MockType: Mock
}
