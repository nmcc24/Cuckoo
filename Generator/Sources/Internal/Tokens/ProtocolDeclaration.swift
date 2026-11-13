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
    /// Requirements of the protocol's or its associated types' `where` clauses that neither constrain an associated
    /// type nor fix one, such as `Items.Element == Int`: the mock and stub repeat them in their own `where` clause.
    var whereRequirements: [String] = []
    /// Whether ``isolation`` is the module's default isolation rather than one the protocol states. A parent's
    /// stated isolation replaces it, as it does in Swift.
    var isIsolationDefault = false
    /// Whether a parent protocol refines `Actor`, which makes this one an actor protocol too.
    var inheritsActor = false
    /// Whether a parent protocol states `Sendable`, which makes this one `Sendable` too.
    var inheritsSendable = false

    /// The global actor the protocol is isolated to, if any.
    var globalActor: String? {
        if case .globalActor(let name)? = isolation { name } else { nil }
    }

    /// Whether the protocol refines `Actor`, so its mock is an `actor`.
    var isActor: Bool {
        inheritsActor || inheritedTypes.contains { $0 == "Actor" || $0 == "_Concurrency.Actor" }
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
            isSuperclassDeclared: isSuperclassDeclared,
            whereRequirements: whereRequirements,
            isIsolationDefault: isIsolationDefault,
            inheritsActor: inheritsActor,
            inheritsSendable: inheritsSendable
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
    
    /// The protocol with the associated types it inherits from `parents`, each with the primary associated types
    /// it's written with, as in `: Parent<String>`. The mock declares inherited associated types as generic
    /// parameters, as it does the protocol's own. One the protocol fixes, with `Parent<String>` or `where Item == String`,
    /// becomes a typealias instead, and a `where Item: Hashable` requirement constrains the generic parameter.
    func inheritingAssociatedTypes(from parents: [(declaration: ProtocolDeclaration, arguments: [String])]) -> ProtocolDeclaration {
        var fixedTypes: [(name: String, type: String)] = []
        var constraints: [String: [String]] = [:]
        var whereRequirements: [String] = []
        for (parent, arguments) in parents {
            fixedTypes += zip(parent.primaryAssociatedTypes, arguments).map { ($0.name, $1) }
        }
        let associatedTypeNames = Set((associatedTypes + primaryAssociatedTypes + parents.flatMap(\.declaration.genericParameters)).map(\.name))
        for requirement in genericRequirements {
            // Inside the mock, `Self.Items` is its generic parameter `Items`.
            let requirement = requirement.replacing(#/\bSelf\./#, with: "")
            let separator = requirement.firstRange(of: "==") ?? requirement.firstRange(of: ":")
            guard let separator else { continue }
            let name = requirement[..<separator.lowerBound].trimmedSpaces
            let type = requirement[separator.upperBound...].trimmedSpaces
            guard associatedTypeNames.contains(name) else {
                // A nested type, as in `Items.Element == Int`: the mock states it in its `where` clause.
                if name != "Self" {
                    whereRequirements.append(requirement)
                }
                continue
            }
            if requirement[separator] == "==" {
                fixedTypes.append((name, type))
            } else {
                constraints[name, default: []].append(type)
            }
        }
        let fixedNames = Set(fixedTypes.map(\.name))
        let inheritedAssociatedTypes = parents.flatMap(\.declaration.genericParameters)

        var protocolDeclaration = self.inheritingIsolation(from: parents.map(\.declaration))
        protocolDeclaration.whereRequirements = (whereRequirements + parents.flatMap(\.declaration.whereRequirements)).uniquing()
        protocolDeclaration.associatedTypes = (associatedTypes + inheritedAssociatedTypes)
            .merged()
            .filter { !fixedNames.contains($0.name) }
            .map { GenericParameter(name: $0.name, inheritedTypes: ($0.inheritedTypes + constraints[$0.name, default: []]).uniquing(), kind: $0.kind) }
        protocolDeclaration.primaryAssociatedTypes = primaryAssociatedTypes.filter { !fixedNames.contains($0.name) }
        // A parent's typealiases arrive with its members; keep one of each.
        var aliases: Set<String> = []
        protocolDeclaration.members = (members + fixedTypes.map { Typealias(alias: $0.name, original: $0.type) as any Token })
            .filter { member in
                guard let typealiasToken = member as? Typealias else { return true }
                return aliases.insert(typealiasToken.alias).inserted
            }
        return protocolDeclaration
    }

    /// The protocol with what its parents make it: an actor protocol if one refines `Actor`, `Sendable` if one is,
    /// and isolated to a parent's global actor unless it states an isolation of its own. Swift infers a protocol's
    /// isolation from the protocols it refines, so a `@MainActor` parent's members stay main-actor isolated.
    private func inheritingIsolation(from parents: [ProtocolDeclaration]) -> ProtocolDeclaration {
        var protocolDeclaration = self
        protocolDeclaration.inheritsActor = inheritsActor || parents.contains(where: \.isActor)
        protocolDeclaration.inheritsSendable = inheritsSendable || parents.contains(where: \.isDeclaredSendable)
        if protocolDeclaration.isActor, isIsolationDefault {
            // An actor protocol is isolated to its conforming actor, never to the default.
            protocolDeclaration.isolation = nil
            protocolDeclaration.isIsolationDefault = false
        } else if isolation == nil || isIsolationDefault,
                  let parentIsolation = parents.first(where: { $0.globalActor != nil && !$0.isIsolationDefault })?.isolation {
            protocolDeclaration.isolation = parentIsolation
            protocolDeclaration.isIsolationDefault = false
        }
        return protocolDeclaration
    }

    var genericParameters: [GenericParameter] {
        (associatedTypes + primaryAssociatedTypes).merged()
    }
    
    var nonPrimaryAssociatedTypes: [GenericParameter] {
        associatedTypes.filter { !primaryAssociatedTypes.map(\.name).contains($0.name) }
    }
}
