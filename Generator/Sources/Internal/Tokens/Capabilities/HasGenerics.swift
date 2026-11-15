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

    /// The `where` clause a mock (and a protocol's stub) repeats, with a leading space, or an empty string.
    var genericWhereClause: String {
        // A class mock repeats the class's own `where` clause, which constrains the generic parameters it subclasses with.
        let requirements = asProtocol?.whereRequirements ?? asClass?.genericRequirements ?? []
        guard !requirements.isEmpty else { return "" }
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

    /// The constraints a protocol mock's generic default-implementation entry points take: each generic parameter
    /// is the static generic type's, and with `metatypes`, a `SendableMetatype`. Without `includingConditional`,
    /// those of the associated types declared under `#if` are left out, for the build where they don't exist.
    func genericProtocolRequirements(metatypes: Bool, includingConditional: Bool) -> [String] {
        let parameters = genericParameters.filter { includingConditional || $0.condition == nil }
        return parameters.map { "\(GeneratedNames.staticGenericParameter).\($0.name) == \($0.name)" }
            + (metatypes ? parameters.map { "\($0.name): SendableMetatype" } : [])
    }

    /// The `#if` condition of the protocol's associated types declared under one, if any.
    var conditionalGenericParameterCondition: String? {
        let conditions = Array(Set(genericParameters.compactMap(\.condition))).sorted()
        return conditions.isEmpty ? nil : conditions.map { "(\($0))" }.joined(separator: " && ")
    }

    /// The lines of a whole declaration whose `where` clause names the generic parameters, once with each set of
    /// them: under the `#if` of the associated types declared under one, and without them in its `#else`.
    func conditionalOnGenericParameters(_ declaration: (_ includingConditional: Bool) -> [String]) -> [String] {
        guard let condition = conditionalGenericParameterCondition else { return declaration(true) }
        return ["#if \(condition)"] + declaration(true) + ["#else"] + declaration(false) + ["#endif"]
    }

    /// A protocol's primary associated types, in angle brackets, or `nil` if it has none.
    var genericPrimaryAssociatedTypeArguments: String? {
        guard let protocolDeclaration = asProtocol, hasPrimaryAssociatedTypes else { return nil }
        return "<\(protocolDeclaration.primaryAssociatedTypes.map { $0.name }.joined(separator: ", "))>"
    }
}
