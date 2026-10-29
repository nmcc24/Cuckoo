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
}

extension Initializer: Inheritable {
    func isEqual(to other: any Inheritable) -> Bool {
        guard let other = other as? Initializer else { return false }
        return signature.isApiEqual(to: other.signature)
    }
}

extension Initializer: Serializable {
    func serialize() -> GeneratorContext {
        let accessibility: Accessibility
        if let parentProtocol = parent?.asProtocol {
            accessibility = parentProtocol.accessibility
        } else {
            accessibility = self.accessibility
        }
        return [
            "documentation": documentation,
            "accessibility": accessibility.sourceName,
            "attributes": repeatedAttributes,
            "spiAttributes": spiAttributes(at: accessibility),
            "signature": signature.description,
            "hasCompilationCondition": hasCompilationCondition,
            "compilationConditionCheck": compilationConditionCheck,
        ]
    }
}
