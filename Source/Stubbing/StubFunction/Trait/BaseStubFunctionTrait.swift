public protocol BaseStubFunctionTrait {
    associatedtype InputType
    associatedtype OutputType
    associatedtype ErrorType: Error
    /// The `then` closure's type. It carries the mock's isolation, e.g. `@MainActor @Sendable (Int) -> String`.
    associatedtype ImplementationType
    /// A ``StubSharing`` type: what `thenReturn` accepts.
    associatedtype Sharing

    var stub: ConcreteStub<InputType, OutputType, ErrorType, ImplementationType> { get }
}
