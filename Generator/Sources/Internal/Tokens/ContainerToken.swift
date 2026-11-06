protocol ContainerToken: Token, HasAttributes, HasAccessibility, HasName, HasGenerics, HasMembers, HasInheritance {}

extension ContainerToken {
    /// The members, with the access level of each accessible one raised to the type's when it's lower.
    var accessibilityAdjustedMembers: [any Token] {
        members.map { child -> any Token in
            guard var member = child as? any Token & HasAccessibility,
                  member.accessibility.isAccessible, member.accessibility < accessibility else { return child }
            member.accessibility = accessibility
            return member
        }
    }

    /// The members a mock and its stub declare, instance members first, then `static` and `class` ones.
    var mockedProperties: [Variable] {
        let variables = accessibilityAdjustedMembers.compactMap { $0 as? Variable }.filter { !$0.isConstant }
        return variables.filter { !$0.isStatic } + variables.filter(\.isStatic)
    }

    var mockedMethods: [Method] {
        let methods = accessibilityAdjustedMembers.compactMap { $0 as? Method }
        return methods.filter { !$0.isStatic } + methods.filter(\.isStatic)
    }

    var mockedSubscripts: [Subscript] {
        let subscripts = accessibilityAdjustedMembers.compactMap { $0 as? Subscript }
        return subscripts.filter { !$0.isStatic } + subscripts.filter(\.isStatic)
    }

    /// A class's initializers are inherited, so only a protocol's are declared.
    var mockedInitializers: [Initializer] {
        isClass ? [] : accessibilityAdjustedMembers.compactMap { $0 as? Initializer }
    }

    /// A protocol's members name `Self` through this typealias; see `Token.resolvingSelf()`.
    var declaresSelfTypealias: Bool {
        asProtocol.map { !$0.isActor } == true
            && (mockedMethods.contains(where: \.mentionsSelf) || mockedProperties.contains(where: \.mentionsSelf)
                || mockedSubscripts.contains(where: \.mentionsSelf))
    }

    func containerSerialize() -> GeneratorContext {
        let accessibilityAdjustedMembers = accessibilityAdjustedMembers

        let typealiases = members.compactMap { ($0 as? Typealias)?.description }

        let variables = accessibilityAdjustedMembers
            .compactMap { $0 as? Variable }
            .filter { !$0.isConstant }

        let initializers = if isClass {
            []
        } else {
            accessibilityAdjustedMembers
                .compactMap { $0 as? Initializer }
                .map { $0.serialize() }
        }

        let allMethods = accessibilityAdjustedMembers.compactMap { $0 as? Method }
        let allSubscripts = accessibilityAdjustedMembers.compactMap { $0 as? Subscript }

        let staticProperties = variables.filter(\.isStatic).map { $0.serialize() }
        let staticMethods = allMethods.filter(\.isStatic).map { $0.serialize() }
        let staticSubscripts = allSubscripts.filter(\.isStatic).map { $0.serialize() }
        let properties = variables.filter { !$0.isStatic }.map { $0.serialize() }
        let methods = allMethods.filter { !$0.isStatic }.map { $0.serialize() }
        let subscripts = allSubscripts.filter { !$0.isStatic }.map { $0.serialize() }

        return [
            "accessibility": accessibility.sourceName,
            "subscripts": subscripts,
            // `static` and `class` members, stubbed through the static proxies.
            "staticProperties": staticProperties,
            "staticMethods": staticMethods,
            "staticSubscripts": staticSubscripts,
            "hasStaticMembers": !(staticProperties.isEmpty && staticMethods.isEmpty && staticSubscripts.isEmpty),
            // Every member, for the mock's body and the nop stub.
            "allProperties": properties + staticProperties,
            "allMethods": methods + staticMethods,
            "allSubscripts": subscripts + staticSubscripts,
            "typealiases": typealiases,
            "declaresSelfTypealias": declaresSelfTypealias,
            "properties": properties,
            "initializers": initializers,
            "methods": methods,
            "attributes": repeatedAttributes,
            "spiAttributes": spiAttributes(at: accessibility),
        ]
        .compactMapValues { $0 }
    }
}
