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
        let usesTypeErasure = container.isGeneric && !container.isClass && !container.hasOnlyPrimaryAssociatedTypes
        let hasStaticMembers = container.mockedProperties.contains(where: \.isStatic)
            || container.mockedMethods.contains(where: \.isStatic) || container.mockedSubscripts.contains(where: \.isStatic)
        let enclosingConditions = (container as? any HasEnclosingCompilationConditions)?.enclosingCompilationConditions ?? []
        let parentName = (container.parent?.value as? any HasName)?.fullyQualifiedName

        var lines: [String] = []
        if !enclosingConditions.isEmpty {
            lines.append("#if \(enclosingConditions.joined(separator: " && "))")
        }
        lines.append(contentsOf: container.repeatedAttributes.map(\.description))
        lines.append(contentsOf: container.spiAttributes(at: container.accessibility).map(\.description))
        if let parentName {
            lines.append("extension \(parentName) {")
        }
        lines.append(header(of: container, isActor: isActor, hasStaticMembers: hasStaticMembers))

        let mocksType = if usesTypeErasure {
            GeneratedNames.typeErasureClassName
        } else if container.isClass {
            "\(container.name)\(container.genericArgumentsString)"
        } else {
            "any \(container.name)\(container.genericArgumentsString)"
        }
        lines.append("    \(access)typealias MocksType = \(mocksType)")
        lines.append("    \(access)typealias Stubbing = __StubbingProxy_\(container.name)")
        lines.append("    \(access)typealias Verification = __VerificationProxy_\(container.name)")
        if container.declaresSelfTypealias {
            lines.append("    \(access)typealias \(SelfResolution.typealiasName) = \(container.mockName)")
        }
        if hasStaticMembers {
            lines.append("    \(access)typealias StaticStubbing = __StaticStubbingProxy_\(container.name)")
            lines.append("    \(access)typealias StaticVerification = __StaticVerificationProxy_\(container.name)")
        }
        lines.append("")
        lines.append("    // Original typealiases")
        lines.append(contentsOf: container.members.compactMap { ($0 as? Typealias).map { "    \(access)\($0.description)" } })
        lines.append("")
        lines.append("    \(access)nonisolated let cuckoo_manager = Cuckoo.MockManager.preconfiguredManager(for: \(container.mockName).self) ?? Cuckoo.MockManager(hasParent: \(container.isClass))")
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
        let nonisolated = isActor ? "" : " nonisolated"
        var header = container.accessibility.spaced
        header += isNonisolatedProtocol ? "nonisolated " : ""
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
        return header + container.genericWhereClause + " {"
    }

    /// The default implementation the mock forwards to, and `enableDefaultImplementation(_:)`, which sets it. An
    /// actor's mock refuses one; a generic protocol's mock stores it in a type-erasing caller.
    private static func defaultImplementation(of container: any ContainerToken, isActor: Bool, usesTypeErasure: Bool, globalActor: String?) throws -> [String] {
        let access = container.accessibility.spaced
        let caller = GeneratedNames.typeErasureClassName
        let generic = GeneratedNames.staticGenericParameter
        let enable = [
            "        __defaultImplStub.value = stub",
            "        cuckoo_manager.enableDefaultStubImplementation()",
            "    }",
        ]
        if isActor {
            return [
                "    \(access)nonisolated func enableDefaultImplementation(_ stub: MocksType) {",
                "        cuckoo_manager.refuseActorDefaultImplementation()",
                "    }",
            ]
        }
        guard usesTypeErasure else {
            let type = "\(container.isClass ? "" : "any ")\(container.name)\(container.genericArgumentsString)"
            return [
                "    nonisolated private let __defaultImplStub = Cuckoo.DefaultImplementation<\(type)>()",
                "",
                "    \(access)nonisolated func enableDefaultImplementation(_ stub: \(type)) {",
            ] + enable
        }

        var lines = [
            "    " + (try TypeErasureBuilder.build(container)),
            "",
            "    nonisolated private let __defaultImplStub = Cuckoo.DefaultImplementation<\(caller)>()",
        ]
        let identity = container.genericProtocolIdentity ?? ""
        if let globalActor, !globalActor.isEmpty {
            // `Mock`'s requirement. Wrapping a default implementation reads it on the global actor, so the generic
            // overload below is isolated to it.
            lines.append("")
            lines.append("    \(access)nonisolated func enableDefaultImplementation(_ stub: \(caller)) {")
            lines.append(contentsOf: enable)
            lines.append("")
            lines.append("    @\(globalActor) \(access)func enableDefaultImplementation<\(generic): \(container.name)>(_ stub: \(generic)) where \(identity) {")
        } else {
            let requirements = container.sendableMetatypeRequirements ?? ""
            lines.append("")
            lines.append("    \(access)nonisolated func enableDefaultImplementation<\(generic): \(container.name) & SendableMetatype>(_ stub: \(generic)) where \(identity)\(requirements) {")
        }
        lines.append("        __defaultImplStub.value = \(caller)(stub)")
        lines.append(contentsOf: enable.dropFirst())
        return lines
    }
}
