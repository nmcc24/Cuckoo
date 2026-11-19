struct Initializer: Token, HasAttributes, HasAccessibility {
    var parent: Reference<any Token>?

    var documentation: [String]
    var attributes: [Attribute]
    var accessibility: Accessibility
    var signature: Method.Signature
    var isRequired: Bool
    var isOptional: Bool
    /// The `#if` conditions the declaration is nested in.
    var compilationConditions: [String] = []
    /// A class's `nonisolated init`, which a subclass under a default isolation has to override as nonisolated.
    var isNonisolated = false
    /// A `convenience init`, which a subclass doesn't override.
    var isConvenience = false
}

extension Initializer: Inheritable {
    func isEqual(to other: any Inheritable) -> Bool {
        guard let other = other as? Initializer else { return false }
        return signature.isApiEqual(to: other.signature)
    }
}
