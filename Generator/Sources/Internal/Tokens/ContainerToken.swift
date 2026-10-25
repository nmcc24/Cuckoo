protocol ContainerToken: Token, HasAttributes, HasAccessibility, HasName, HasGenerics, HasMembers, HasInheritance {}

extension ContainerToken {
    func containerSerialize() -> GeneratorContext {
        func withAdjustedAccessibility<TokenType: HasAccessibility>(token: TokenType) -> TokenType {
            // We only want to adjust tokens that are accessible and lower than the enclosing type
            guard token.accessibility.isAccessible && token.accessibility < accessibility else { return token }
            var mutableToken = token
            mutableToken.accessibility = accessibility
            return mutableToken
        }

        let accessibilityAdjustedMembers = members.map { child -> any Token in
            guard let memberWithAccessibility = child as? any Token & HasAccessibility else { return child }
            return withAdjustedAccessibility(token: memberWithAccessibility)
        }

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
            "properties": properties,
            "initializers": initializers,
            "methods": methods,
            "attributes": attributes,
        ]
        .compactMapValues { $0 }
    }
}
