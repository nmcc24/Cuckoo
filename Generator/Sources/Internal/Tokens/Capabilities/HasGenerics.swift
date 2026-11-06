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
            .map { "\(Templates.staticGenericParameter).\($0.name) == \($0.name)" }
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

    func genericsSerialize() -> GeneratorContext {
        return [
            "isGeneric": isGeneric,
            "genericParameters": genericParametersString,
            "genericArguments": genericArgumentsString,
            "hasPrimaryAssociatedTypes": hasPrimaryAssociatedTypes,
            "hasOnlyPrimaryAssociatedTypes": hasOnlyPrimaryAssociatedTypes,
            "genericProtocolIdentity": genericProtocolIdentity as Any,
            "sendableMetatypeRequirements": sendableMetatypeRequirements as Any,
        ]
        .compactMapValues { $0 }
    }
}
