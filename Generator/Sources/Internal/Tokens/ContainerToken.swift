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

}
