import SwiftSyntax

/// Builds `__DefaultImplCaller`, which erases the type of a generic protocol's default implementation.
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
        let name = GeneratedNames.typeErasureClassName
        let globalActor = container.asProtocol?.globalActor
        let context = Context(
            access: container.accessibility.spaced,
            sendable: globalActor == nil ? "@Sendable " : "",
            protocolName: container.name,
            primaryArguments: container.genericPrimaryAssociatedTypeArguments ?? "",
            globalActor: globalActor
        )
        let properties = container.mockedProperties.filter { !$0.isStatic }
        let methods = container.mockedMethods.filter { !$0.isStatic }
        let subscripts = container.mockedSubscripts.filter { !$0.isStatic }
        var members = MemberList()

        if container.declaresSelfTypealias {
            try members.append("\(context.access)typealias \(SelfResolution.typealiasName) = \(name)", of: name)
        }
        try members.append("private let cuckooManager: Cuckoo.MockManager", of: name)
        try members.append("private let cuckooReference: \(context.sendable)() -> any \(container.name)\(context.primaryArguments)", of: name)
        if Self.storesThroughReference(subscripts, context) {
            // A generic setter changes the opened default implementation and stores it back, so a value type keeps it.
            try members.append("private let cuckooStore: \(context.sendable)(any \(container.name)\(context.primaryArguments)) -> Void", of: name)
        }

        for property in properties {
            try append(property, sources(of: property, context), of: "\(container.name).\(property.name)", to: &members)
        }
        for (index, subscriptDeclaration) in subscripts.enumerated() {
            try append(subscriptDeclaration, sources(of: subscriptDeclaration, number: index + 1, context), of: "\(container.name)[]", to: &members)
        }

        members.separate()
        try members.append(initializer(container, properties: properties, subscripts: subscripts, methods: methods, globalActor: globalActor, context), of: "\(name).init")
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

        // Forwarding to a deprecated requirement is the eraser's job, not a use the deprecation warns about. Only Swift
        // 6.4 has a way to say so; older compilers keep the warning.
        let hasDeprecatedRequirement = container.mockedProperties.contains { $0.attributes.contains(where: \.isDeprecated) }
            || container.mockedMethods.contains { $0.attributes.contains(where: \.isDeprecated) }
            || container.mockedSubscripts.contains { $0.attributes.contains(where: \.isDeprecated) }
        let ignoringDeprecations = hasDeprecatedRequirement
            ? "#if hasAttribute(diagnose)\n@diagnose(DeprecatedDeclaration, as: ignored)\n#endif\n" : ""
        let header = if let globalActor {
            "\(ignoringDeprecations)@\(globalActor) \(context.access)final class \(name): \(container.name) {\n}"
        } else {
            "\(ignoringDeprecations)\(context.access)nonisolated final class \(name): \(container.name), Sendable {\n}"
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
        /// The eraser's global actor, or nil when it's nonisolated.
        var globalActor: String?

        /// Why a member can't be forwarded to the opened default implementation, or nil when it can: such a member
        /// records a failure saying to stub it and returns a default value, so the mock still compiles.
        func unforwardableReason(
            isolation: Isolation?,
            mentionsSelf: Bool,
            hasInout: Bool = false,
            hasSending: Bool = false,
            hasNoncopyable: Bool = false,
            hasIsolatedParameter: Bool = false,
            execution: String? = nil,
            hasTypedThrows: Bool = false
        ) -> String? {
            if hasInout {
                return "it takes an inout argument"
            }
            if hasSending {
                return "it takes a sending argument, which a stored closure can't pass on"
            }
            if hasNoncopyable {
                return "it takes a ~Copyable argument, which a stored closure can't pass on"
            }
            if hasIsolatedParameter {
                return "it takes an isolated parameter, which a stored closure can't pass on"
            }
            if mentionsSelf {
                return "it names Self, which the eraser isn't"
            }
            if isolatedDifferently(isolation) || execution?.isEmpty == false {
                return "it's isolated differently from the protocol"
            }
            if hasTypedThrows {
                return "it throws a typed error, which a stored closure can't pass on"
            }
            return nil
        }

        private func isolatedDifferently(_ isolation: Isolation?) -> Bool {
            guard let isolation else { return false }
            return isolation != globalActor.map(Isolation.globalActor) ?? .nonisolated
        }

        /// The isolation and execution attributes a member repeats where they differ from the eraser's, so it
        /// satisfies the requirement: `nonisolated` in a global actor's eraser, `@MainActor` in a nonisolated one.
        func modifier(for isolation: Isolation?, execution: String? = nil) -> String {
            var attributes: [String] = []
            if let isolation, isolatedDifferently(isolation) {
                attributes.append(isolation.sourceDescription)
            }
            if let execution, !execution.isEmpty {
                attributes.append(execution)
            }
            return attributes.map { "\($0) " }.joined()
        }
    }

    /// The name of a member's stored closure, without the backticks a keyword-named member is written with. A raw
    /// identifier's characters that a plain identifier can't hold, such as a space, become `$` and their code point.
    static func storageName(_ name: String) -> String {
        name.filter { $0 != "`" }.unicodeScalars.map { scalar in
            scalar == "_" || scalar.properties.isAlphabetic || ("0"..."9").contains(scalar) ? String(scalar) : "$\(scalar.value)"
        }.joined()
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
        let storage = storageName(property.name)
        let getterEffects = property.effects.getterDeclaration
        var declaration = property.spiAttributes(at: property.accessibility).map(\.description)
        declaration.append("\(context.access)\(context.modifier(for: property.isolation))var \(property.name): \(type) {")
        if let reason = unforwardableReason(of: property, context) {
            declaration.append("    get \(getterEffects){ return \(unforwardableCall("\(context.protocolName).\(property.name)", reason: reason, returning: property.type)) }")
            if !property.isReadOnly {
                declaration.append("    set { \(unforwardableCall("\(context.protocolName).\(property.name)", reason: reason, returning: nil)) as Void }")
            }
            declaration.append("}")
            return [lines(declaration)]
        }
        // The stored closure throws untyped errors, as a method's does: the getter narrows a typed one back.
        let closureEffects = (property.effects.isAsync ? "async " : "") + (property.effects.isThrowing ? "throws " : "")
        let tryAwait = (property.effects.isThrowing ? "try " : "") + (property.effects.isAsync ? "await " : "")
        var sources = ["private let _getter_storage$$\(storage): \(context.sendable)() \(closureEffects)-> \(type)"]
        if !property.isReadOnly {
            sources.append("private let _setter_storage$$\(storage): \(context.sendable)(\(type)) -> Void")
        }
        if let typedError = property.effects.typedError {
            declaration.append("    get \(getterEffects){")
            declaration.append("        do {")
            declaration.append("            return \(tryAwait)_getter_storage$$\(storage)()")
            declaration.append("        } catch {")
            declaration.append("            throw Cuckoo.MockManager.typedError(error, as: (\(typedError)).self, member: \(Fragment.literal("\(context.protocolName).\(property.name)")))")
            declaration.append("        }")
            declaration.append("    }")
        } else {
            declaration.append("    get \(getterEffects){ return \(tryAwait)_getter_storage$$\(storage)() }")
        }
        if !property.isReadOnly {
            declaration.append("    set { _setter_storage$$\(storage)(newValue) }")
        }
        declaration.append("}")
        sources.append(lines(declaration))
        return sources
    }

    /// The manager call that stands in for forwarding `member`: it records a failure on the mock's manager and returns
    /// the default an unstubbed call would.
    private static func unforwardableCall(_ member: String, reason: String, returning type: ComplexType?) -> String {
        let tuple = GeneratorHelper.unstubbedTupleArgument(for: type).map { ", \($0)" } ?? ""
        return "cuckooManager.unforwardableDefaultImplementationCall(\(Fragment.literal(member)), reason: \(Fragment.literal(reason))\(tuple))"
    }

    private static func unforwardableReason(of property: Variable, _ context: Context) -> String? {
        context.unforwardableReason(isolation: property.isolation, mentionsSelf: property.mentionsSelf)
    }

    private static func unforwardableReason(of method: Method, _ context: Context) -> String? {
        context.unforwardableReason(
            isolation: method.isolation,
            mentionsSelf: method.mentionsSelf,
            hasInout: method.signature.parameters.contains(where: \.isInout),
            // A generic member calls the opened default implementation directly and passes a `sending` argument on;
            // only a stored closure can't.
            hasSending: !method.hasGenericParams && method.signature.parameters.contains(where: \.isSending),
            hasNoncopyable: method.hasNoncopyableParams,
            hasIsolatedParameter: method.signature.parameters.contains { $0.type.containsAttribute(named: "isolated") },
            execution: method.executionAttribute
        )
    }

    private static func unforwardableReason(of subscriptDeclaration: Subscript, _ context: Context) -> String? {
        context.unforwardableReason(
            isolation: subscriptDeclaration.isolation,
            mentionsSelf: subscriptDeclaration.mentionsSelf,
            hasNoncopyable: subscriptDeclaration.getter.hasNoncopyableParams,
            hasTypedThrows: subscriptDeclaration.throwType?.isTyped == true
        )
    }

    private static func sources(of subscriptDeclaration: Subscript, number: Int, _ context: Context) -> [String] {
        if let reason = unforwardableReason(of: subscriptDeclaration, context) {
            let call = unforwardableCall(subscriptDeclaration.getter.fullyQualifiedName, reason: reason, returning: subscriptDeclaration.returnType)
            var declaration = subscriptDeclaration.spiAttributes(at: subscriptDeclaration.accessibility).map(\.description)
            declaration.append("\(context.access)\(context.modifier(for: subscriptDeclaration.isolation))subscript\(subscriptDeclaration.signature) {")
            declaration.append("    get \(subscriptDeclaration.getterEffects){ return \(call) }")
            if !subscriptDeclaration.isReadOnly {
                let setterCall = unforwardableCall(subscriptDeclaration.setter.fullyQualifiedName, reason: reason, returning: nil)
                declaration.append("    set { \(setterCall) as Void }")
            }
            declaration.append("}")
            return [lines(declaration)]
        }
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
        // An opened type's view of the keys, the result and the new value, which name the protocol's associated types.
        let generic = GeneratedNames.staticGenericParameter
        let nonPrimary = getter.parent?.asProtocol?.nonPrimaryAssociatedTypes.map(\.name) ?? []
        let opened: (String) -> String = { "\(generic).\($0)" }
        let castArguments = getter.signature.parameters.map { $0.callAndCastTypes(named: nonPrimary, as: opened) }.joined(separator: ", ")
        func castResult(_ expression: String) -> String {
            subscriptDeclaration.returnType.containsTypes(named: nonPrimary) ? expression.forceCast(as: subscriptDeclaration.returnType) : expression
        }
        let castNewValue = subscriptDeclaration.returnType.replaceTypes(named: nonPrimary, with: opened).map { "newValue".forceCast(as: $0) } ?? "newValue"
        var declaration = subscriptDeclaration.spiAttributes(at: subscriptDeclaration.accessibility).map(\.description)
        declaration.append("\(context.access)\(context.modifier(for: subscriptDeclaration.isolation))subscript\(subscriptDeclaration.signature) {")
        declaration.append("    get \(effects){")
        let variadicCrash = "Cuckoo.MockManager.crashOnVariadicArgumentForward(\(Fragment.literal(getter.fullyQualifiedName)))"
        let unforwardable = unforwardableCall(getter.fullyQualifiedName, reason: getter.unforwardableWhereClauseReason, returning: subscriptDeclaration.returnType)
        if isGeneric && getter.hasVariadicParams {
            declaration.append("        \(variadicCrash)")
        } else if isGeneric && !getter.associatedTypesInWhereClause.isEmpty {
            declaration.append("        return \(unforwardable)")
        } else if isGeneric && getter.usesNonPrimaryAssociatedTypes {
            // Through `any P` an associated type reads as `Any`: the opened type gives it back, as for methods.
            declaration.append("        func openExistential<\(generic): \(context.protocolName)\(context.primaryArguments)>(_ opened: \(generic))\(effects.trimmedSpaces.isEmpty ? "" : " \(effects.trimmedSpaces)") -> \(returnType) {")
            declaration.append("            return \(tryAwait)\(castResult("opened[\(castArguments)]"))")
            declaration.append("        }")
            declaration.append("        return \(tryAwait)openExistential(cuckooReference())")
        } else if isGeneric {
            declaration.append("        return \(tryAwait)cuckooReference()[\(forwardingCall)]")
        } else {
            declaration.append("        return \(tryAwait)_subscript_getter_storage$$\(number)(\(getter.parameterNames))")
        }
        declaration.append("    }")
        if !subscriptDeclaration.isReadOnly {
            declaration.append("    set {")
            if isGeneric && getter.hasVariadicParams {
                declaration.append("        \(variadicCrash) as Void")
            } else if isGeneric && !getter.associatedTypesInWhereClause.isEmpty {
                declaration.append("        \(unforwardable) as Void")
            } else if isGeneric && getter.usesNonPrimaryAssociatedTypes {
                // Set on the opened value, which is stored back, as a non-generic subscript's setter sets the box's.
                declaration.append("        func openExistential<\(generic): \(context.protocolName)\(context.primaryArguments)>(_ opened: \(generic)) -> any \(context.protocolName)\(context.primaryArguments) {")
                declaration.append("            var opened = opened")
                declaration.append("            opened[\(castArguments)] = \(castNewValue)")
                declaration.append("            return opened")
                declaration.append("        }")
                declaration.append("        cuckooStore(openExistential(cuckooReference()))")
            } else if isGeneric {
                declaration.append("        var reference = cuckooReference()")
                declaration.append("        reference[\(forwardingCall)] = newValue")
                declaration.append("        cuckooStore(reference)")
            } else {
                declaration.append("        _subscript_setter_storage$$\(number)(\(getter.parameterNames)\(newValueSeparator)newValue)")
            }
            declaration.append("    }")
        }
        declaration.append("}")
        sources.append(lines(declaration))
        return sources
    }

    /// Whether a generic subscript has a setter, which can't be stored as a closure and stores the changed default
    /// implementation back instead.
    private static func storesThroughReference(_ subscripts: [Subscript], _ context: Context) -> Bool {
        subscripts.contains {
            !$0.genericParameters.isEmpty && !$0.isReadOnly && !$0.getter.hasVariadicParams && unforwardableReason(of: $0, context) == nil
        }
    }

    /// The initializer, which stores a closure for each requirement that reads the default implementation from the
    /// box. Generic requirements are called on `cuckooReference()` instead, as a generic closure can't be stored.
    private static func initializer(
        _ container: any ContainerToken,
        properties: [Variable],
        subscripts: [Subscript],
        methods: [Method],
        globalActor: String?,
        _ context: Context
    ) -> String {
        let generic = GeneratedNames.staticGenericParameter
        let metatype = globalActor == nil ? " & SendableMetatype" : ""
        var body = [
            "let box = Cuckoo.DefaultImplementation<\(generic)>()",
            "box.value = defaultImpl",
            "cuckooReference = { box.value }",
            "cuckooManager = manager",
        ]
        if storesThroughReference(subscripts, context) {
            body.append("cuckooStore = { box.value = $0 as! \(generic) }")
        }
        body.append("")
        func conditional(_ token: any HasAttributes, _ statements: [String]) -> [String] {
            token.hasCompilationCondition ? [token.compilationConditionCheck] + statements + ["#endif"] : statements
        }
        for property in properties where unforwardableReason(of: property, context) == nil {
            let tryAwait = (property.effects.isThrowing ? "try " : "") + (property.effects.isAsync ? "await " : "")
            var statements = ["_getter_storage$$\(storageName(property.name)) = { \(tryAwait)box.value.\(property.name) }"]
            if !property.isReadOnly {
                statements.append("_setter_storage$$\(storageName(property.name)) = { box.value.\(property.name) = $0 }")
            }
            body.append(contentsOf: conditional(property, statements))
        }
        for (index, subscriptDeclaration) in subscripts.enumerated()
            where subscriptDeclaration.genericParameters.isEmpty && unforwardableReason(of: subscriptDeclaration, context) == nil {
            let number = index + 1
            let tryAwait = (subscriptDeclaration.throwType != nil ? "try " : "") + (subscriptDeclaration.isAsync ? "await " : "")
            let keys = subscriptDeclaration.keyClosureParameters
            var statements: [String]
            if subscriptDeclaration.getter.hasVariadicParams {
                // Swift can't pass the recorded array on as separate arguments.
                let crash = "Cuckoo.MockManager.crashOnVariadicArgumentForward(\(Fragment.literal(subscriptDeclaration.getter.fullyQualifiedName)))"
                let ignored = Array(repeating: "_", count: subscriptDeclaration.parameters.count).joined(separator: ", ")
                statements = ["_subscript_getter_storage$$\(number) = { \(ignored) in \(crash) }"]
                if !subscriptDeclaration.isReadOnly {
                    statements.append("_subscript_setter_storage$$\(number) = { \(ignored), _ in \(crash) as Void }")
                }
            } else {
                statements = ["_subscript_getter_storage$$\(number) = { \(tryAwait)box.value[\(keys)] }"]
                if !subscriptDeclaration.isReadOnly {
                    statements.append("_subscript_setter_storage$$\(number) = { box.value[\(keys)] = $\(subscriptDeclaration.parameters.count) }")
                }
            }
            body.append(contentsOf: conditional(subscriptDeclaration, statements))
        }
        for (index, method) in methods.enumerated() where !method.hasGenericParams && unforwardableReason(of: method, context) == nil {
            let parameters = method.parameterNames.isEmpty ? "" : "\(method.parameterNames) in "
            let tryAwait = (method.isThrowing ? "try " : "") + (method.isAsync ? "await " : "")
            // Swift can't pass a variadic parameter's recorded array on as separate arguments.
            let statement = if method.hasVariadicParams {
                "_storage$\(index + 1)$\(storageName(method.name)) = { \(parameters)Cuckoo.MockManager.crashOnVariadicArgumentForward(\(Fragment.literal(method.fullyQualifiedName))) }"
            } else {
                "_storage$\(index + 1)$\(storageName(method.name)) = { \(parameters)\(tryAwait)box.value.\(escapeReservedKeywords(for: method.name))(\(method.call)) }"
            }
            body.append(contentsOf: conditional(method, [statement]))
        }
        let source = container.conditionalOnGenericParameters { holding in
            let requirements = container.genericProtocolRequirements(metatypes: globalActor == nil, holding: holding)
            return ["init<\(generic): \(container.name)\(metatype)>(_ defaultImpl: \(generic), manager: Cuckoo.MockManager)\(MockBuilder.whereClause(requirements)) {"]
                + body.map { $0.isEmpty ? "" : "    \($0)" } + ["}"]
        }
        return lines(source)
    }

    private static func sources(of method: Method, number: Int, _ context: Context) -> [String] {
        let generic = GeneratedNames.staticGenericParameter
        let returnType = method.returnType?.description ?? ""
        let effects = (method.isAsync ? " async" : "") + (method.isThrowing ? " throws" : "")
        let tryAwait = (method.isThrowing ? "try " : "") + (method.isAsync ? "await " : "")
        let storage = "_storage$\(number)$\(storageName(method.name))"
        let unforwardable = unforwardableReason(of: method, context)
        var sources: [String] = []
        if !method.hasGenericParams && unforwardable == nil {
            sources.append("private let \(storage): \(context.sendable)(\(method.inputTypes))\(effects) -> \(returnType)")
        }
        var declaration = method.spiAttributes(at: method.accessibility).map(\.description)
        declaration.append("\(context.access)\(context.modifier(for: method.isolation, execution: method.executionAttribute))func \(escapeReservedKeywords(for: method.name))\(method.signature.description) {")
        if let unforwardable {
            declaration.append("    return \(unforwardableCall(method.fullyQualifiedName, reason: unforwardable, returning: method.returnType))")
        } else if method.hasVariadicParams && method.hasGenericParams {
            declaration.append("    Cuckoo.MockManager.crashOnVariadicArgumentForward(\(Fragment.literal(method.fullyQualifiedName)))")
        } else if method.hasGenericParams && !method.associatedTypesInWhereClause.isEmpty {
            declaration.append("    return \(unforwardableCall(method.fullyQualifiedName, reason: method.unforwardableWhereClauseReason, returning: method.returnType))")
        } else if method.hasGenericParams && method.usesNonPrimaryAssociatedTypes {
            // A `sending` argument is passed in rather than captured: a captured value can't be sent on.
            let sendingDeclarations = method.sendingParameterDeclarations.map { ", \($0)" }.joined()
            declaration.append("    func openExistential<\(generic): \(context.protocolName)\(context.primaryArguments)>(_ opened: \(generic)\(sendingDeclarations))\(effects) -> \(returnType) {")
            declaration.append("        return \(tryAwait)opened.\(method.name)\(method.staticGenericCall)")
            declaration.append("    }")
            let sendingNames = method.sendingParameterNames.map { ", \($0)" }.joined()
            declaration.append("    return \(tryAwait)openExistential(cuckooReference()\(sendingNames))")
        } else if method.hasGenericParams {
            declaration.append("    return \(tryAwait)cuckooReference().\(method.name)(\(method.call))")
        } else if let throwType = method.signature.throwType, throwType.isTyped {
            // The stored closure throws untyped errors: a typed-throws function type needs runtime support that iOS 17
            // lacks once it's a stored property's type. The method narrows it back, as the mock's members do.
            declaration.append("    do {")
            declaration.append("        return \(tryAwait)\(storage)(\(method.parameterNames))")
            declaration.append("    } catch {")
            declaration.append("        throw Cuckoo.MockManager.typedError(error, as: (\(throwType.type)).self, member: \(Fragment.literal(method.fullyQualifiedName)))")
            declaration.append("    }")
        } else {
            declaration.append("    return \(tryAwait)\(storage)(\(method.parameterNames))")
        }
        declaration.append("}")
        sources.append(lines(declaration))
        return sources
    }

    private static func staticSource(of property: Variable, _ context: Context) -> String {
        let crash = "Cuckoo.MockManager.crashOnStaticDefaultImplementationCall(\(Fragment.literal(property.name)))"
        let effects = property.effects.getterDeclaration
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
        source.append("\(context.access)static \(method.declaration)\(method.signature.description) {")
        // Returned, so the result type is inferred from the method's, `Void` included.
        source.append("    return Cuckoo.MockManager.crashOnStaticDefaultImplementationCall(\(Fragment.literal(method.fullyQualifiedName)))")
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
