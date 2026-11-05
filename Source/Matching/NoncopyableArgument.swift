/// What a mock records for a `~Copyable` argument, which it can't copy into its recorded calls.
///
/// The recorded call and its matchers see this placeholder, so match the argument with `any()`. A `then` closure
/// receives the argument itself, borrowed, except for a generic `T: ~Copyable` argument or an `inout` one, which
/// get the placeholder.
public struct NoncopyableArgument: Sendable, Equatable, CustomStringConvertible {
    /// The argument's type, as the mocked declaration spells it.
    public let type: String

    /// Creates the placeholder for an argument of `type`.
    public init(type: String) {
        self.type = type
    }

    /// How failure messages show the argument, such as `<~Copyable Token>`.
    public var description: String {
        "<~Copyable \(type)>"
    }
}
