/// Builds a mocked type's whole output: the mock, with its members and proxies, then its nop stub, inside the
/// extension of the type it's nested in and the `#if` it's declared under.
///
/// The other builders make the pieces. This one lays them out line by line, and `GeneratorHelper.format` lays the
/// file out, so the pieces' own lines keep the indentation they were built with.
enum MockBuilder {
    static func build(_ container: any ContainerToken, keepDocumentation: Bool) throws -> String {
        let access = container.accessibility.spaced
        let isActor = container.asProtocol?.isActor == true
        let globalActor = container.asProtocol?.globalActor
        // An actor's mock refuses a default implementation, so it names the protocol itself and needs no type eraser.
        let usesTypeErasure = container.isGeneric && !container.isClass && !container.hasOnlyPrimaryAssociatedTypes && !isActor
        let hasStaticMembers = container.mockedProperties.contains(where: \.isStatic)
            || container.mockedMethods.contains(where: \.isStatic) || container.mockedSubscripts.contains(where: \.isStatic)
        let enclosingConditions = (container as? any HasEnclosingCompilationConditions)?.enclosingCompilationConditions ?? []
        let parentName = (container.parent?.value as? any HasName)?.fullyQualifiedName

        var lines: [String] = []
        if !enclosingConditions.isEmpty {
            lines.append("#if \(enclosingConditions.joined(separator: " && "))")
        }
        // The enclosing types' and extensions' availability, which the extension of the type the mock is nested in
        // needs as their members do, and the `where` clauses of the extensions it's declared in.
        var enclosingAttributes: [Attribute] = []
        var enclosingRequirements: [String] = []
        var ancestor = container.parent?.value
        while let current = ancestor {
            enclosingAttributes.insert(contentsOf: (current as? any HasAttributes)?.repeatedAttributes ?? [], at: 0)
            // On an extension of a type nested deeper, `Self` names the extension's own type.
            let requirements = (current as? NamespaceDeclaration)?.genericRequirements ?? []
            let name = (current as? any HasName)?.fullyQualifiedName
            enclosingRequirements.insert(contentsOf: name == parentName ? requirements : requirements.map { $0.replacing(/\bSelf\b/.wordBoundaryKind(.simple), with: name ?? "Self") }, at: 0)
            ancestor = current.parent?.value
        }
        lines.append(contentsOf: (enclosingAttributes + container.repeatedAttributes).uniquing().map(\.description))
        lines.append(contentsOf: container.spiAttributes(at: container.accessibility).map(\.description))
        if let parentName {
            lines.append("extension \(parentName)\(enclosingRequirements.isEmpty ? "" : " where " + enclosingRequirements.joined(separator: ", ")) {")
        }
        lines.append(header(of: container, isActor: isActor, hasStaticMembers: hasStaticMembers))

        let mocksType = if usesTypeErasure {
            GeneratedNames.typeErasureClassName
        } else if container.isClass {
            "\(container.name)\(container.genericArgumentsString)"
        } else {
            // Only primary associated types can constrain the existential.
            "any \(container.name)\(container.genericPrimaryAssociatedTypeArguments ?? "")"
        }
        lines.append("    \(access)typealias CuckooMocksType = \(mocksType)")
        lines.append("    \(access)typealias CuckooStubbing = \(container.derivedName("__StubbingProxy_"))")
        lines.append("    \(access)typealias CuckooVerification = \(container.derivedName("__VerificationProxy_"))")
        if container.declaresSelfTypealias {
            lines.append("    \(access)typealias \(SelfResolution.typealiasName) = \(container.mockName)")
        }
        if hasStaticMembers {
            lines.append("    \(access)typealias CuckooStaticStubbing = \(container.derivedName("__StaticStubbingProxy_"))")
            lines.append("    \(access)typealias CuckooStaticVerification = \(container.derivedName("__StaticVerificationProxy_"))")
        }
        lines.append("")
        let unknownAttributes = container.asClass?.unknownAttributes ?? container.asProtocol?.unknownAttributes ?? []
        if !unknownAttributes.isEmpty {
            let names = unknownAttributes.map { "@\($0)" }.joined(separator: ", ")
            lines.append("    // \(container.name) is marked \(names), which Cuckoo doesn't recognise, so this mock ignores it. If one of")
            lines.append("    // them is a global actor declared in another module, add it to the module's `globalActors` in the Cuckoofile.")
            lines.append("")
        }
        if let outside = container.asProtocol?.parentsOutsideSources, !outside.isEmpty {
            let names = outside.map { "'\($0)'" }.joined(separator: ", ")
            lines.append("    // \(container.name) inherits \(names), declared outside the mocked sources, so this mock and")
            lines.append("    // \(container.name)Stub only implement requirements that have default implementations. If they don't")
            lines.append("    // conform, add the missing members to them in an extension in the test target.")
            lines.append("")
        }
        if let type = container.asClass?.internalMockReason {
            lines.append("    // This mock is internal: \(container.name)'s non-public members name '\(type)', which the module declares")
            lines.append("    // non-public, and a public override can't. Import the mocks' module with `@testable` to use it.")
            lines.append("")
        }
        if let unmockedMembers = container.asClass?.unmockedMembers, !unmockedMembers.isEmpty {
            lines.append("    // Not mocked, so calls run the real implementation:")
            lines.append(contentsOf: unmockedMembers.map { "    // - \($0)" })
            lines.append("")
        }
        // A class mock inherits the class's typealiases, as its stub does, and a copy would read its names in the
        // mock's scope instead of the class's.
        if !container.isClass {
            lines.append("    // Original typealiases")
            lines.append(contentsOf: container.members.compactMap { ($0 as? Typealias).map { "    \(access)\($0.description)" } })
            lines.append("")
        }
        if !container.outerScopeTypealiases.isEmpty {
            lines.append("    // The types of the scopes around \((container.parent?.value as? any HasName)?.name ?? ""), which this extension doesn't see")
            lines.append(contentsOf: container.outerScopeTypealiases.flatMap { $0.source(access: access).split(separator: "\n").map { "    \($0)" } })
            lines.append("")
        }
        lines.append("    \(access)nonisolated let cuckooManager = Cuckoo.MockManager.preconfiguredManager(for: \(container.mockName).self) ?? Cuckoo.MockManager(hasParent: \(container.isClass))")
        if let initializer = container.crossModuleInitializer(isActor: isActor) {
            lines.append("    \(initializer)")
        }
        for initializer in container.nonisolatedInitializerOverrides {
            lines.append(contentsOf: initializer.split(separator: "\n").map { "    \($0)" })
        }
        if case .globalActor(let name)? = container.declaredIsolation, !isActor {
            // Checks that read the recorded calls of several mocks at once, such as `verifyNoMoreInteractions`,
            // can't take one mock's isolation, so they ask for it at run time.
            lines.append("    \(access)nonisolated static var cuckooGlobalActor: (any Actor)? { \(name).shared }")
        }
        lines.append("")
        lines.append(contentsOf: try defaultImplementation(of: container, isActor: isActor, usesTypeErasure: usesTypeErasure, globalActor: globalActor))
        lines.append("")
        lines.append("    " + (try MockMembersBuilder.build(container, options: .init(keepDocumentation: keepDocumentation))))
        lines.append("")
        lines.append("    " + (try StubbingProxyBuilder.build(container, isStatic: false)))
        lines.append("")
        lines.append("    " + (try VerificationProxyBuilder.build(container, isStatic: false)))
        if hasStaticMembers {
            lines.append("")
            lines.append("    " + (try StubbingProxyBuilder.build(container, isStatic: true)))
            lines.append("")
            lines.append("    " + (try VerificationProxyBuilder.build(container, isStatic: true)))
        }
        lines.append("}")
        lines.append("")
        lines.append(try NopImplStubBuilder.build(container))
        lines.append("")
        if parentName != nil {
            lines.append("}")
        }
        if !enclosingConditions.isEmpty {
            lines.append("#endif")
        }
        lines.append("")
        return lines.joined(separator: "\n") + "\n"
    }

    /// The mock's declaration line: an `actor` for an actor protocol, otherwise a `final class`, conforming to the
    /// mocked type and Cuckoo's mock protocols.
    private static func header(of container: any ContainerToken, isActor: Bool, hasStaticMembers: Bool) -> String {
        let isNonisolatedProtocol = container.asProtocol.map { protocolDeclaration in
            // Its mock and stub are explicitly `nonisolated`, so they don't take on the module's default isolation
            // (`-default-isolation MainActor`). A subclass of a declared class takes on that class's isolation instead.
            !protocolDeclaration.isActor && (protocolDeclaration.isolation == nil || protocolDeclaration.isolation == .nonisolated)
                && !protocolDeclaration.isSuperclassDeclared
        } ?? false
        // A class nonisolated because the type it's nested in is: the mock, in an extension of that type, wouldn't
        // infer it from the class.
        let isNonisolatedClass = container.asClass?.isolation == .nonisolated
        let nonisolated = isActor ? "" : " nonisolated"
        var header = container.accessibility.spaced
        header += isNonisolatedProtocol || isNonisolatedClass ? "nonisolated " : ""
        header += isActor ? "actor" : "final class"
        header += " \(container.mockName)\(container.genericParametersString):"
        if let superclass = container.asProtocol?.superclass, !superclass.isEmpty {
            header += " \(superclass),"
        }
        header += " \(container.name)\(container.isClass ? container.genericArgumentsString : ""),"
        header += "\(nonisolated) \(container.isClass ? "Cuckoo.ClassMock" : "Cuckoo.ProtocolMock")"
        if hasStaticMembers {
            header += ",\(nonisolated) Cuckoo.StaticMock"
        }
        return header + container.restatedUncheckedSendable + container.genericWhereClause + " {"
    }

    /// The default implementation the mock forwards to, and `enableDefaultImplementation(_:)`, which sets it. An
    /// actor's mock refuses one; a generic protocol's mock stores it in a type-erasing caller.
    private static func defaultImplementation(of container: any ContainerToken, isActor: Bool, usesTypeErasure: Bool, globalActor: String?) throws -> [String] {
        let access = container.accessibility.spaced
        let caller = GeneratedNames.typeErasureClassName
        let generic = GeneratedNames.staticGenericParameter
        let enable = [
            "        cuckooDefaultImplementation.value = stub",
            "        cuckooManager.enableDefaultImplementation()",
            "    }",
        ]
        if isActor {
            return [
                "    \(access)nonisolated func enableDefaultImplementation(_ stub: CuckooMocksType) {",
                "        cuckooManager.refuseActorDefaultImplementation()",
                "    }",
            ]
        }
        guard usesTypeErasure else {
            let type = container.isClass ? "\(container.name)\(container.genericArgumentsString)"
                : "any \(container.name)\(container.genericPrimaryAssociatedTypeArguments ?? "")"
            return [
                "    nonisolated private let cuckooDefaultImplementation = Cuckoo.__CuckooDefaultImplementation<\(type)>()",
                "",
                "    \(access)nonisolated func enableDefaultImplementation(_ stub: \(type)) {",
            ] + enable
        }

        var lines = [
            "    " + (try TypeErasureBuilder.build(container)),
            "",
            "    nonisolated private let cuckooDefaultImplementation = Cuckoo.__CuckooDefaultImplementation<\(caller)>()",
        ]
        if let globalActor, !globalActor.isEmpty {
            // `Mock`'s requirement. Wrapping a default implementation reads it on the global actor, so the generic
            // overload below is isolated to it.
            lines.append("")
            lines.append("    \(access)nonisolated func enableDefaultImplementation(_ stub: \(caller)) {")
            lines.append(contentsOf: enable)
            lines.append("")
            lines.append(contentsOf: container.conditionalOnGenericParameters { holding in
                let requirements = container.genericProtocolRequirements(metatypes: false, holding: holding)
                return ["    @\(globalActor) \(access)func enableDefaultImplementation<\(generic): \(container.name)>(_ stub: \(generic))\(Self.whereClause(requirements)) {",
                        "        cuckooDefaultImplementation.value = \(caller)(stub, manager: cuckooManager)"] + enable.dropFirst()
            })
        } else {
            lines.append("")
            lines.append(contentsOf: container.conditionalOnGenericParameters { holding in
                let requirements = container.genericProtocolRequirements(metatypes: true, holding: holding)
                return ["    \(access)nonisolated func enableDefaultImplementation<\(generic): \(container.name) & SendableMetatype>(_ stub: \(generic))\(Self.whereClause(requirements)) {",
                        "        cuckooDefaultImplementation.value = \(caller)(stub, manager: cuckooManager)"] + enable.dropFirst()
            })
        }
        return lines
    }

    /// ` where a, b`, or nothing for no requirements.
    static func whereClause(_ requirements: [String]) -> String {
        requirements.isEmpty ? "" : " where " + requirements.joined(separator: ", ")
    }
}
