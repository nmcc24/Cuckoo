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

    /// The initializer a public or package mock or stub declares so another module can create it, which can't see
    /// an implicit internal one, or nil when it needs none. A protocol's is `nonisolated`, as the implicit one is,
    /// unless it's an actor's, whose initializer can't be. One that subclasses a declared class inherits that class's
    /// initializers, unless its only one is the implicit `init()`, which it then overrides.
    func crossModuleInitializer(isActor: Bool) -> String? {
        guard accessibility >= .package else { return nil }
        let access = accessibility.spaced
        guard let protocolDeclaration = asProtocol else {
            return asClass?.hasOnlyImplicitInitializer == true ? "\(access)nonisolated override init() { super.init() }" : nil
        }
        if let superclass = protocolDeclaration.superclass, !superclass.isEmpty {
            return protocolDeclaration.superclassHasOnlyImplicitInitializer ? "\(access)nonisolated override init() { super.init() }" : nil
        }
        guard !mockedInitializers.contains(where: { $0.signature.parameters.isEmpty }) else { return nil }
        return "\(access)\(isActor ? "" : "nonisolated ")init() {}"
    }

    /// A protocol's members name `Self` through this typealias; see `Token.resolvingSelf()`.
    var declaresSelfTypealias: Bool {
        asProtocol.map { !$0.isActor } == true
            && (mockedMethods.contains(where: \.mentionsSelf) || mockedProperties.contains(where: \.mentionsSelf)
                || mockedSubscripts.contains(where: \.mentionsSelf))
    }

}
