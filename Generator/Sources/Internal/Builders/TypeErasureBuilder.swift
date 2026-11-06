import SwiftSyntax

/// Builds `DefaultImplCaller`, which erases the type of a generic protocol's default implementation.
///
/// Its closures share one `Cuckoo.DefaultImplementation` box, which is `Sendable`, so the closures are `@Sendable`
/// and the caller is checked `Sendable`, as a mock of a `Sendable` generic protocol needs. A protocol isolated to a
/// global actor gets a caller isolated to it, which is `Sendable` and can read the requirements. Every closure reads
/// the default implementation from the box when it runs, and a mutating requirement writes it back, so a value-type
/// default implementation keeps its changes.
///
/// Like ``NopImplStubBuilder``, each member is parsed as it's built, and `GeneratorHelper.format` lays the file out.
enum TypeErasureBuilder {
    static func build(_ container: any ContainerToken) throws -> String {
        let name = Templates.typeErasureClassName
        let globalActor = container.asProtocol?.globalActor
        let context = Context(
            access: container.accessibility.spaced,
            sendable: globalActor == nil ? "@Sendable " : "",
            protocolName: container.name,
            primaryArguments: container.genericPrimaryAssociatedTypeArguments ?? ""
        )
        let properties = container.mockedProperties.filter { !$0.isStatic }
        let methods = container.mockedMethods.filter { !$0.isStatic }
        let subscripts = container.mockedSubscripts.filter { !$0.isStatic }
        var members = MemberList()

        if container.declaresSelfTypealias {
            try members.append("\(context.access)typealias \(SelfResolution.typealiasName) = \(name)", of: name)
        }
        try members.append("private let reference: \(context.sendable)() -> any \(container.name)\(context.primaryArguments)", of: name)

        for property in properties {
            try append(property, sources(of: property, context), of: "\(container.name).\(property.name)", to: &members)
        }
        for (index, subscriptDeclaration) in subscripts.enumerated() {
            try append(subscriptDeclaration, sources(of: subscriptDeclaration, number: index + 1, context), of: "\(container.name)[]", to: &members)
        }

        members.separate()
        try members.append(initializer(container, properties: properties, subscripts: subscripts, methods: methods, globalActor: globalActor), of: "\(name).init")
        for (index, initializer) in container.mockedInitializers.enumerated() {
            let access = initializer.parent?.asProtocol?.accessibility ?? initializer.accessibility
            var source = index == 0 ? ["/// MARK:- ignored required initializers"] : []
            var declaration = initializer.spiAttributes(at: access).map(\.description)
            declaration.append("\(context.access)required init\(initializer.signature.description) {")
            declaration.append("    fatalError(\"`\(name)` class is only used for calling default implementation and can't be initialized on its own.\")")
            declaration.append("}")
            source.append(members.conditional(initializer, lines(declaration)))
            try members.append(lines(source), of: "\(container.name).init\(initializer.signature.description)")
        }

        for (index, method) in methods.enumerated() {
            try append(method, sources(of: method, number: index + 1, context), of: "\(container.name).\(method.name)", to: &members)
        }
        for property in container.mockedProperties where property.isStatic {
            try append(property, [staticSource(of: property, context)], of: "\(container.name).\(property.name)", to: &members)
        }
        for method in container.mockedMethods where method.isStatic {
            try append(method, [staticSource(of: method, context)], of: "\(container.name).\(method.name)", to: &members)
        }
        for subscriptDeclaration in container.mockedSubscripts where subscriptDeclaration.isStatic {
            try append(subscriptDeclaration, [staticSource(of: subscriptDeclaration, context)], of: "\(container.name)[]", to: &members)
        }

        let header = if let globalActor {
            "@\(globalActor) \(context.access)final class \(name): \(container.name) {\n}"
        } else {
            "\(context.access)nonisolated final class \(name): \(container.name), Sendable {\n}"
        }
        guard var classDeclaration = try Fragment.declaration(header, of: name).as(ClassDeclSyntax.self) else {
            throw FragmentError.unparsable(declaration: name, source: header)
        }
        classDeclaration.memberBlock.members = members.list
        return classDeclaration.description
    }

    private struct Context {
        /// The container's access level, spaced.
        var access: String
        /// `@Sendable ` for a nonisolated caller's closures.
        var sendable: String
        var protocolName: String
        var primaryArguments: String
    }

    /// A member's declarations, after a blank line: inside its `#if` as one member, or each on its own line.
    private static func append(_ token: any HasAttributes, _ sources: [String], of declaration: String, to members: inout MemberList) throws {
        members.separate()
        if token.hasCompilationCondition {
            try members.append(members.conditional(token, lines(sources)), of: declaration)
        } else {
            for source in sources {
                try members.append(source, of: declaration)
            }
        }
    }

    private static func sources(of property: Variable, _ context: Context) -> [String] {
        let type = property.type.description
        var sources = ["private let _getter_storage$$\(property.name): \(context.sendable)() -> \(type)"]
        if !property.isReadOnly {
            sources.append("private let _setter_storage$$\(property.name): \(context.sendable)(\(type)) -> Void")
        }
        var declaration = property.spiAttributes(at: property.accessibility).map(\.description)
        declaration.append("\(context.access)var \(property.name): \(type) {")
        declaration.append("    get { return _getter_storage$$\(property.name)() }")
        if !property.isReadOnly {
            declaration.append("    set { _setter_storage$$\(property.name)(newValue) }")
        }
        declaration.append("}")
        sources.append(lines(declaration))
        return sources
    }

    private static func sources(of subscriptDeclaration: Subscript, number: Int, _ context: Context) -> [String] {
        let isGeneric = !subscriptDeclaration.genericParameters.isEmpty
        let keyTypes = subscriptDeclaration.keyTypes
        let returnType = subscriptDeclaration.returnType.description
        let getter = subscriptDeclaration.getter
        let effects = subscriptDeclaration.getterEffects
        let tryAwait = (subscriptDeclaration.throwType != nil ? "try " : "") + (subscriptDeclaration.isAsync ? "await " : "")
        let newValueSeparator = keyTypes.isEmpty ? "" : ", "
        var sources: [String] = []
        if !isGeneric {
            sources.append("private let _subscript_getter_storage$$\(number): \(context.sendable)(\(keyTypes)) \(effects)-> \(returnType)")
            if !subscriptDeclaration.isReadOnly {
                sources.append("private let _subscript_setter_storage$$\(number): \(context.sendable)(\(keyTypes)\(newValueSeparator)\(returnType)) -> Void")
            }
        }
        let forwardingCall = getter.signature.parameters.map(\.forwardingCall).joined(separator: ", ")
        var declaration = subscriptDeclaration.spiAttributes(at: subscriptDeclaration.accessibility).map(\.description)
        declaration.append("\(context.access)subscript\(subscriptDeclaration.signature) {")
        declaration.append("    get \(effects){")
        if isGeneric {
            declaration.append("        return \(tryAwait)reference()[\(forwardingCall)]")
        } else {
            declaration.append("        return \(tryAwait)_subscript_getter_storage$$\(number)(\(getter.parameterNames))")
        }
        declaration.append("    }")
        if !subscriptDeclaration.isReadOnly {
            declaration.append("    set {")
            if isGeneric {
                declaration.append("        var reference = reference()")
                declaration.append("        reference[\(forwardingCall)] = newValue")
            } else {
                declaration.append("        _subscript_setter_storage$$\(number)(\(getter.parameterNames)\(newValueSeparator)newValue)")
            }
            declaration.append("    }")
        }
        declaration.append("}")
        sources.append(lines(declaration))
        return sources
    }

    /// The initializer, which stores a closure for each requirement that reads the default implementation from the
    /// box. Generic requirements are called on `reference()` instead, as a generic closure can't be stored.
    private static func initializer(
        _ container: any ContainerToken,
        properties: [Variable],
        subscripts: [Subscript],
        methods: [Method],
        globalActor: String?
    ) -> String {
        let generic = Templates.staticGenericParameter
        let metatype = globalActor == nil ? " & SendableMetatype" : ""
        let requirements = (container.genericProtocolIdentity ?? "") + (globalActor == nil ? container.sendableMetatypeRequirements ?? "" : "")
        var body = [
            "let box = Cuckoo.DefaultImplementation<\(generic)>()",
            "box.value = defaultImpl",
            "reference = { box.value }",
            "",
        ]
        func conditional(_ token: any HasAttributes, _ statements: [String]) -> [String] {
            token.hasCompilationCondition ? [token.compilationConditionCheck] + statements + ["#endif"] : statements
        }
        for property in properties {
            var statements = ["_getter_storage$$\(property.name) = { box.value.\(property.name) }"]
            if !property.isReadOnly {
                statements.append("_setter_storage$$\(property.name) = { box.value.\(property.name) = $0 }")
            }
            body.append(contentsOf: conditional(property, statements))
        }
        for (index, subscriptDeclaration) in subscripts.enumerated() where subscriptDeclaration.genericParameters.isEmpty {
            let number = index + 1
            let tryAwait = (subscriptDeclaration.throwType != nil ? "try " : "") + (subscriptDeclaration.isAsync ? "await " : "")
            let keys = subscriptDeclaration.keyClosureParameters
            var statements = ["_subscript_getter_storage$$\(number) = { \(tryAwait)box.value[\(keys)] }"]
            if !subscriptDeclaration.isReadOnly {
                statements.append("_subscript_setter_storage$$\(number) = { box.value[\(keys)] = $\(subscriptDeclaration.parameters.count) }")
            }
            body.append(contentsOf: conditional(subscriptDeclaration, statements))
        }
        for (index, method) in methods.enumerated() where !method.hasGenericParams {
            let parameters = method.parameterNames.isEmpty ? "" : "\(method.parameterNames) in "
            let tryAwait = (method.isThrowing ? "try " : "") + (method.isAsync ? "await " : "")
            let statement = "_storage$\(index + 1)$\(method.name) = { \(parameters)\(tryAwait)box.value.\(escapeReservedKeywords(for: method.name))(\(method.call)) }"
            body.append(contentsOf: conditional(method, [statement]))
        }
        var source = ["init<\(generic): \(container.name)\(metatype)>(_ defaultImpl: \(generic)) where \(requirements) {"]
        source.append(contentsOf: body.map { $0.isEmpty ? "" : "    \($0)" })
        source.append("}")
        return lines(source)
    }

    private static func sources(of method: Method, number: Int, _ context: Context) -> [String] {
        let generic = Templates.staticGenericParameter
        let returnType = method.returnType?.description ?? ""
        let effects = (method.isAsync ? " async" : "") + (method.isThrowing ? " throws" : "")
        let tryAwait = (method.isThrowing ? "try " : "") + (method.isAsync ? "await " : "")
        let storage = "_storage$\(number)$\(method.name)"
        var sources: [String] = []
        if !method.hasGenericParams {
            sources.append("private let \(storage): \(context.sendable)(\(method.inputTypes))\(effects) -> \(returnType)")
        }
        var declaration = method.spiAttributes(at: method.accessibility).map(\.description)
        declaration.append("\(context.access)func \(escapeReservedKeywords(for: method.name))\(method.signature.description) {")
        if method.hasGenericParams && method.usesNonPrimaryAssociatedTypes {
            // A `sending` argument is passed in rather than captured: a captured value can't be sent on.
            let variants = method.localFunctionVariants
            let sendingDeclarations = method.sendingParameterDeclarations.map { ", \($0)" }.joined()
            for variant in variants {
                if !variant.directive.isEmpty {
                    declaration.append("    \(variant.directive)")
                }
                declaration.append("    \(variant.modifier)func openExistential<\(generic): \(context.protocolName)\(context.primaryArguments)>(_ opened: \(generic)\(sendingDeclarations))\(effects) -> \(returnType) {")
                declaration.append("        return \(tryAwait)opened.\(method.name)\(method.staticGenericCall)")
                declaration.append("    }")
            }
            if variants.count > 1 {
                declaration.append("    #endif")
            }
            let sendingNames = method.sendingParameterNames.map { ", \($0)" }.joined()
            declaration.append("    return \(tryAwait)openExistential(reference()\(sendingNames))")
        } else if method.hasGenericParams {
            declaration.append("    return \(tryAwait)reference().\(method.name)(\(method.call))")
        } else {
            declaration.append("    return \(tryAwait)\(storage)(\(method.parameterNames))")
        }
        declaration.append("}")
        sources.append(lines(declaration))
        return sources
    }

    private static func staticSource(of property: Variable, _ context: Context) -> String {
        let crash = "Cuckoo.MockManager.crashOnStaticDefaultImplementationCall(\(Fragment.literal(property.name)))"
        let effects = (property.effects.isAsync ? "async " : "") + (property.effects.isThrowing ? "throws " : "")
        var source = property.spiAttributes(at: property.accessibility).map(\.description)
        source.append("\(context.access)static var \(property.name): \(property.type.description) {")
        source.append("    get \(effects){ \(crash) }")
        if !property.isReadOnly {
            source.append("    set { \(crash) as Void }")
        }
        source.append("}")
        return lines(source)
    }

    private static func staticSource(of method: Method, _ context: Context) -> String {
        var source = method.spiAttributes(at: method.accessibility).map(\.description)
        source.append("\(context.access)static func \(escapeReservedKeywords(for: method.name))\(method.signature.description) {")
        source.append("    Cuckoo.MockManager.crashOnStaticDefaultImplementationCall(\(Fragment.literal(method.fullyQualifiedName)))")
        source.append("}")
        return lines(source)
    }

    private static func staticSource(of subscriptDeclaration: Subscript, _ context: Context) -> String {
        var source = subscriptDeclaration.spiAttributes(at: subscriptDeclaration.accessibility).map(\.description)
        source.append("\(context.access)static subscript\(subscriptDeclaration.signature) {")
        source.append("    get \(subscriptDeclaration.getterEffects){ Cuckoo.MockManager.crashOnStaticDefaultImplementationCall(\(Fragment.literal(subscriptDeclaration.getter.fullyQualifiedName))) }")
        if !subscriptDeclaration.isReadOnly {
            source.append("    set { Cuckoo.MockManager.crashOnStaticDefaultImplementationCall(\(Fragment.literal(subscriptDeclaration.setter.fullyQualifiedName))) as Void }")
        }
        source.append("}")
        return lines(source)
    }

    private static func lines(_ lines: [String]) -> String {
        lines.joined(separator: "\n")
    }
}
