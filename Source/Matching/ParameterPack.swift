/// The arguments a mock received for a parameter pack (`repeat each T`), recorded as one value.
///
/// Match a pack with ``anyPack()``, with ``equal(toPack:)`` when its values are `Equatable`, or with a
/// `ParameterMatcher` over the whole pack. A `then` closure receives the pack as one `ParameterPack` too.
public struct ParameterPack: CustomStringConvertible {
    /// The pack's values, in order.
    public let values: [Any]

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

    public subscript(index: Int) -> Any {
        values[index]
    }

    public var description: String {
        "(\(values.map { String(describing: $0) }.joined(separator: ", ")))"
    }
}

/// Returns a matcher matching any parameter pack.
public func anyPack() -> ParameterMatcher<ParameterPack> {
    ParameterMatcher()
}

/// Returns a matcher matching a parameter pack whose values equal `values`, in order and with the same types.
public func equal<each Value: Equatable>(toPack values: repeat each Value) -> ParameterMatcher<ParameterPack> {
    var expected: [(Any) -> Bool] = []
    for value in repeat each values {
        expected.append(isEqual(to: value))
    }
    return ParameterMatcher { pack in
        pack.count == expected.count && zip(expected, pack.values).allSatisfy { matches, value in matches(value) }
    }
}

private func isEqual<Value: Equatable>(to expected: Value) -> (Any) -> Bool {
    { ($0 as? Value) == expected }
}
