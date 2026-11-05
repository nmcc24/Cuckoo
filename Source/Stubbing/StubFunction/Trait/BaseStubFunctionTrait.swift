/// What every stubbing handle has: the member's types and its stub.
public protocol BaseStubFunctionTrait {
    /// The member's arguments, as a tuple for several parameters.
    associatedtype InputType
    /// The member's return type.
    associatedtype OutputType
    /// The error the member throws, `Never` if it doesn't.
    associatedtype ErrorType: Error
    /// The `then` closure's type. It carries the mock's isolation, e.g. `@MainActor @Sendable (Int) -> String`.
    associatedtype ImplementationType
    /// A ``StubSharing`` type: what `thenReturn` accepts.
    associatedtype Sharing

    /// The stub the `then…` calls add answers to.
    var stub: ConcreteStub<InputType, OutputType, ErrorType, ImplementationType> { get }
}
