struct ProtocolDeclaration: ContainerToken, HasEnclosingCompilationConditions {
    var parent: Reference<any Token>?

    var attributes: [Attribute]
    var accessibility: Accessibility
    var name: String
    var associatedTypes: [GenericParameter]
    var primaryAssociatedTypes: [GenericParameter]
    var genericRequirements: [String]
    var inheritedTypes: [String]
    var members: [any Token]
    var enclosingCompilationConditions: [String]
    /// The global actor the type is isolated to, if any.
    var isolation: Isolation?
    /// The class every conforming type must inherit from, which the mock and stub then subclass: a class the
    /// protocol names, directly or through another protocol, or `NSObject` for an `NSObjectProtocol`.
    var superclass: String?
    /// Whether ``superclass`` is declared in the sources. The mock then takes on the class's isolation, as
    /// a subclass must, instead of being `nonisolated`.
    var isSuperclassDeclared = false

    /// Whether the protocol refines `Actor`, so its mock is an `actor`.
    var isActor: Bool {
        inheritedTypes.contains { $0 == "Actor" || $0 == "_Concurrency.Actor" }
    }

    func replacing(members: [any Token]) -> ProtocolDeclaration {
        ProtocolDeclaration(
            parent: parent,
            attributes: attributes,
            accessibility: accessibility,
            name: name,
            associatedTypes: associatedTypes,
            primaryAssociatedTypes: primaryAssociatedTypes,
            genericRequirements: genericRequirements,
            inheritedTypes: inheritedTypes,
            members: members,
            enclosingCompilationConditions: enclosingCompilationConditions,
            isolation: isolation,
            superclass: superclass,
            isSuperclassDeclared: isSuperclassDeclared
        )
    }

    /// The protocol bound to `superclass`, with `declaration` when the class is declared in the sources. Its
    /// isolation becomes the protocol's, unless the protocol states its own.
    func replacing(superclass: String, declaration: ClassDeclaration?) -> ProtocolDeclaration {
        var protocolDeclaration = self
        protocolDeclaration.superclass = superclass
        protocolDeclaration.isSuperclassDeclared = declaration != nil
        protocolDeclaration.isolation = isolation ?? declaration?.isolation
        return protocolDeclaration
    }
    
    var genericParameters: [GenericParameter] {
        (associatedTypes + primaryAssociatedTypes).merged()
    }
    
    var nonPrimaryAssociatedTypes: [GenericParameter] {
        associatedTypes.filter { !primaryAssociatedTypes.map(\.name).contains($0.name) }
    }
}
