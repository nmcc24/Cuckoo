/// The arguments a mock received for a parameter pack (`repeat each T`), recorded as one value.
///
/// Match a pack with `any()`, with `equal(to:)` when its values are `Equatable`, or with a
/// `ParameterMatcher` over the whole pack. A `then` closure receives the pack as one `ParameterPack` too.
public struct ParameterPack: CustomStringConvertible {
    /// The pack's values, in order.
    public let values: [Any]

    /// Records `values` as one pack.
    public init<each Value>(_ values: repeat each Value) {
        var collected: [Any] = []
        for value in repeat each values {
            collected.append(value)
        }
        self.values = collected
    }

    /// The number of values in the pack.
    public var count: Int {
        values.count
    }

    /// The value at `index`.
    public subscript(index: Int) -> Any {
        values[index]
    }

    /// The values, comma-separated in parentheses, as in failure messages.
    public var description: String {
        "(\(values.map { String(describing: $0) }.joined(separator: ", ")))"
    }
}

/// Returns a matcher matching a parameter pack whose values equal `values`, in order and with the same types.
public func equal<each Value: Equatable & Sendable>(to values: repeat each Value) -> ParameterMatcher<ParameterPack> {
    var matchers: [@Sendable (Any) -> Bool] = []
    for value in repeat each values {
        matchers.append(isEqual(to: value))
    }
    let expected = matchers
    return ParameterMatcher { pack in
        pack.count == expected.count && zip(expected, pack.values).allSatisfy { matches, value in matches(value) }
    }
}

private func isEqual<Value: Equatable & Sendable>(to expected: Value) -> @Sendable (Any) -> Bool {
    { ($0 as? Value) == expected }
}
