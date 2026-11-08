/// A token's link to the declaration it's nested in. The crawler creates it once, with the parent as it was declared
/// (before its members are crawled), and nothing changes it afterwards, so tokens can cross the tasks that generate
/// files concurrently.
@dynamicMemberLookup
final class Reference<Value: Sendable>: Sendable {
    let value: Value

    init(_ value: Value) {
        self.value = value
    }

    subscript<T>(dynamicMember keyPath: KeyPath<Value, T>) -> T {
        value[keyPath: keyPath]
    }
}

extension Reference: Equatable where Value: Equatable {
    static func == (lhs: Reference<Value>, rhs: Reference<Value>) -> Bool {
        lhs.value == rhs.value
    }
}
