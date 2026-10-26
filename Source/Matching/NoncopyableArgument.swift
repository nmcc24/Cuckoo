/// What a mock records for a `~Copyable` argument, which it can't copy into its recorded calls.
///
/// Match it with `any()`. A `then` closure receives this placeholder instead of the argument.
public struct NoncopyableArgument: Sendable, Equatable, CustomStringConvertible {
    /// The argument's type, as the mocked declaration spells it.
    public let type: String

    public init(type: String) {
        self.type = type
    }

    public var description: String {
        "<~Copyable \(type)>"
    }
}
