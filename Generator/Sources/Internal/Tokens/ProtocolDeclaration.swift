import Foundation

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

    /// The global actor the protocol is isolated to, if any.
    var globalActor: String? {
        if case .globalActor(let name)? = isolation { name } else { nil }
    }

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
    
    /// The protocol with the associated types it inherits from `parents`, each with the primary associated types
    /// it's written with, as in `: Parent<String>`. The mock declares inherited associated types as generic
    /// parameters, as it does the protocol's own. One the protocol fixes, with `Parent<String>` or `where Item == String`,
    /// becomes a typealias instead, and a `where Item: Hashable` requirement constrains the generic parameter.
    func inheritingAssociatedTypes(from parents: [(declaration: ProtocolDeclaration, arguments: [String])]) -> ProtocolDeclaration {
        var fixedTypes: [(name: String, type: String)] = []
        var constraints: [String: [String]] = [:]
        for (parent, arguments) in parents {
            fixedTypes += zip(parent.primaryAssociatedTypes, arguments).map { ($0.name, $1) }
        }
        for requirement in genericRequirements {
            let separator = requirement.range(of: "==") ?? requirement.range(of: ":")
            guard let separator else { continue }
            var name = requirement[..<separator.lowerBound].trimmingCharacters(in: .whitespaces)
            if name.hasPrefix("Self.") {
                name.removeFirst("Self.".count)
            }
            let type = requirement[separator.upperBound...].trimmingCharacters(in: .whitespaces)
            if requirement[separator] == "==" {
                fixedTypes.append((name, type))
            } else {
                constraints[name, default: []].append(type)
            }
        }
        let fixedNames = Set(fixedTypes.map(\.name))
        let inheritedAssociatedTypes = parents.flatMap(\.declaration.genericParameters)

        var protocolDeclaration = self
        protocolDeclaration.associatedTypes = (associatedTypes + inheritedAssociatedTypes)
            .merged()
            .filter { !fixedNames.contains($0.name) }
            .map { GenericParameter(name: $0.name, inheritedTypes: ($0.inheritedTypes + constraints[$0.name, default: []]).uniquing(), isPack: $0.isPack) }
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

    var genericParameters: [GenericParameter] {
        (associatedTypes + primaryAssociatedTypes).merged()
    }
    
    var nonPrimaryAssociatedTypes: [GenericParameter] {
        associatedTypes.filter { !primaryAssociatedTypes.map(\.name).contains($0.name) }
    }
}
