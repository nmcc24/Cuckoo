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
    /// is the static generic type's, and with `metatypes`, a `SendableMetatype`. With `holding`, an associated type
    /// declared under `#if` takes part only when its condition is one of those, for the build where it exists.
    func genericProtocolRequirements(metatypes: Bool, holding conditions: Set<String>? = nil) -> [String] {
        let parameters = genericParameters.filter { parameter in
            parameter.condition.map { conditions?.contains($0) ?? true } ?? true
        }
        return parameters.map { "\(GeneratedNames.staticGenericParameter).\($0.name) == \($0.name)" }
            + (metatypes ? parameters.map { "\($0.name): SendableMetatype" } : [])
    }

    /// The `#if` conditions of the protocol's associated types declared under one.
    var genericParameterConditions: [String] {
        Array(Set(genericParameters.compactMap(\.condition))).sorted()
    }

    /// The lines of a whole declaration whose `where` clause names the generic parameters, once for each
    /// combination of the conditions the associated types are declared under: `declaration` gets the conditions
    /// that hold in that branch, or nil when no associated type is conditional.
    func conditionalOnGenericParameters(_ declaration: (_ holding: Set<String>?) -> [String]) -> [String] {
        let conditions = genericParameterConditions
        guard !conditions.isEmpty else { return declaration(nil) }
        var lines: [String] = []
        let combinations = 1 << conditions.count
        for mask in (0..<combinations).reversed() {
            let holding = Set(conditions.indices.filter { mask & (1 << $0) != 0 }.map { conditions[$0] })
            let clause = conditions.map { holding.contains($0) ? "(\($0))" : "!(\($0))" }.joined(separator: " && ")
            lines.append(mask == combinations - 1 ? "#if \(clause)" : mask == 0 ? "#else" : "#elseif \(clause)")
            lines.append(contentsOf: declaration(holding))
        }
        return lines + ["#endif"]
    }

    /// A protocol's primary associated types, in angle brackets, or `nil` if it has none.
    var genericPrimaryAssociatedTypeArguments: String? {
        guard let protocolDeclaration = asProtocol, hasPrimaryAssociatedTypes else { return nil }
        return "<\(protocolDeclaration.primaryAssociatedTypes.map { $0.name }.joined(separator: ", "))>"
    }
}
