protocol HasGenerics: Token {
    var genericParameters: [GenericParameter] { get }
    var genericRequirements: [String] { get }
}

extension HasGenerics {
    var genericParametersString: String {
        guard !genericParameters.isEmpty else { return "" }
        let parameters = genericParameters.map { $0.description }.joined(separator: ", ")
        return "<\(parameters)>"
    }

    /// The `where` clause a protocol's mock and stub repeat, with a leading space, or an empty string.
    var genericWhereClause: String {
        guard let requirements = asProtocol?.whereRequirements, !requirements.isEmpty else { return "" }
        return " where " + requirements.joined(separator: ", ")
    }

    var genericArgumentsString: String {
        guard !genericParameters.isEmpty else { return "" }
        let arguments = genericParameters.map { $0.name }.joined(separator: ", ")
        return "<\(arguments)>"
    }

    var isGeneric: Bool {
        !genericParameters.isEmpty
    }
    
    var hasPrimaryAssociatedTypes: Bool {
        guard let protocolDeclaration = asProtocol else { return false }
        return !protocolDeclaration.primaryAssociatedTypes.isEmpty
    }
    
    var hasOnlyPrimaryAssociatedTypes: Bool {
        guard let protocolDeclaration = asProtocol else { return false }
        return protocolDeclaration.primaryAssociatedTypes.count == protocolDeclaration.genericParameters.count
    }

    /// The `where` constraints that make a protocol's generic parameters the static generic type's, or `nil` for a
    /// class.
    var genericProtocolIdentity: String? {
        guard isProtocol else { return nil }
        return genericParameters
            .map { "\(GeneratedNames.staticGenericParameter).\($0.name) == \($0.name)" }
            .joined(separator: ", ")
    }

    /// A nonisolated `DefaultImplCaller`'s `@Sendable` closures capture these parameters' metatypes. `nil` for a class.
    var sendableMetatypeRequirements: String? {
        guard isProtocol else { return nil }
        return genericParameters.map { ", \($0.name): SendableMetatype" }.joined()
    }

    /// A protocol's primary associated types, in angle brackets, or `nil` if it has none.
    var genericPrimaryAssociatedTypeArguments: String? {
        guard let protocolDeclaration = asProtocol, hasPrimaryAssociatedTypes else { return nil }
        return "<\(protocolDeclaration.primaryAssociatedTypes.map { $0.name }.joined(separator: ", "))>"
    }

}
