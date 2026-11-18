protocol ContainerToken: Token, HasAttributes, HasAccessibility, HasName, HasGenerics, HasMembers, HasInheritance {
    var outerScopeTypealiases: [OuterScopeTypealias] { get }
}

/// A typealias a mock and its stub declare for a type of an outer scope, `Model = Feature.Model`, under the `#if`
/// conditions the type is declared in.
struct OuterScopeTypealias: Sendable {
    let declaration: String
    let conditions: [String]

    /// The declaration at `access`, inside its `#if` when it has one.
    func source(access: String) -> String {
        let alias = "\(access)typealias \(declaration)"
        return conditions.isEmpty ? alias : "#if \(conditions.joined(separator: " && "))\n\(alias)\n#endif"
    }
}

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

    /// `, @unchecked Sendable` when the mock and stub subclass an `@unchecked Sendable` class, which a subclass has
    /// to restate, or nothing.
    var restatedUncheckedSendable: String {
        asClass?.isUncheckedSendable == true || asProtocol?.isSuperclassUncheckedSendable == true ? ", @unchecked Sendable" : ""
    }

    /// The initializer a public or package protocol's mock or stub declares so another module can create it, which
    /// can't see the implicit internal one, or nil when it needs none. It's `nonisolated`, as the implicit one is,
    /// unless it's an actor's, whose initializer can't be. One that subclasses a class inherits the class's
    /// initializers: a class whose only one is its implicit, internal `init()` can't be created from another module
    /// either, and needs a `public init()` of its own.
    func crossModuleInitializer(isActor: Bool) -> String? {
        guard accessibility >= .package, let protocolDeclaration = asProtocol,
              (protocolDeclaration.superclass ?? "").isEmpty else { return nil }
        let access = accessibility.spaced
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
