import SwiftSyntax

/// Builds the mock's own members: its properties, initializers, methods and subscripts, each of which records the call
/// with the mock manager and runs the stub.
///
/// Like ``NopImplStubBuilder``, each member is parsed as it's built, and `GeneratorHelper.format` lays the file out.
/// A method's nested closures for non-escaping closure parameters open and close inside its one member, so no fragment
/// opens a block another closes.
enum MockMembersBuilder {
    struct Options {
        /// Whether members keep their documentation comments.
        var keepDocumentation: Bool
    }

    static func build(_ container: any ContainerToken, options: Options) throws -> String {
        let context = Context(container: container, options: options)
        var members = MemberList()

        for property in container.mockedProperties {
            members.separate()
            try members.append(classLevel(members.conditional(property, source(of: property, context))), of: "\(container.name).\(property.name)")
        }
        members.separate()
        for initializer in container.mockedInitializers {
            try members.append(classLevel(members.conditional(initializer, source(of: initializer, context))), of: "\(container.name).init\(initializer.signature.description)")
        }
        for method in container.mockedMethods {
            members.separate()
            try members.append(classLevel(members.conditional(method, source(of: method, context))), of: "\(container.name).\(method.name)")
        }
        for subscriptDeclaration in container.mockedSubscripts {
            members.separate()
            try members.append(classLevel(members.conditional(subscriptDeclaration, source(of: subscriptDeclaration, context))), of: "\(container.name)[]")
        }
        // The list drops each member's first indentation, which the template's line doesn't give back.
        let indented = members.list.map { member in
            let newlines = member.leadingTrivia.pieces.prefix { $0.isNewline }
            let rest = member.leadingTrivia.pieces.dropFirst(newlines.count)
            return member.with(\.leadingTrivia, Trivia(pieces: Array(newlines) + [.spaces(4)] + Array(rest)))
        }
        return MemberBlockItemListSyntax(indented).description
    }

    private struct Context {
        var container: any ContainerToken
        var options: Options

        var isClass: Bool { container.isClass }
        var isActor: Bool { container.asProtocol?.isActor == true }
    }

    /// The member's documentation, if the options keep it.
    private static func comments(of token: any Token, documentation: [String], _ context: Context) -> [String] {
        context.options.keepDocumentation ? documentation.map { "/// \($0)" } : []
    }

    /// The attributes every copy repeats, the `@_spi` ones at its access level, and its isolation.
    private static func attributes(of member: any HasAttributes, at access: Accessibility, isolation: Isolation?) -> [String] {
        var attributes = member.repeatedAttributes.map(\.description) + member.spiAttributes(at: access).map(\.description)
        if let isolation = isolation?.sourceDescription, !isolation.isEmpty {
            attributes.append(isolation)
        }
        return attributes
    }

    /// A class's own members override the superclass's; a protocol's members it inherits don't.
    private static func modifiers(of member: any Token, isStatic: Bool) -> String {
        (member.parent?.isClass == true ? "override " : "") + (isStatic ? "static " : "")
    }

    private static func manager(isStatic: Bool) -> String {
        isStatic ? "cuckoo_staticManager" : "cuckoo_manager"
    }

    private static func source(of property: Variable, _ context: Context) -> String {
        let name = property.name
        let literal = Fragment.literal(name)
        let tryAwait = (property.effects.isThrowing ? "try " : "") + (property.effects.isAsync ? "await " : "")
        let effects = (property.effects.isAsync ? "async " : "") + (property.effects.isThrowing ? "throws " : "")
        let types = property.implementationTypes
        let isolated = property.stubIsolation.isolatedParameter != nil
        let manager = manager(isStatic: property.isStatic)

        func defaultCall(_ forwarding: String) -> String {
            if property.isStatic {
                "Cuckoo.MockManager.crashOnStaticDefaultImplementationCall(\(literal))"
            } else if context.isActor {
                "Cuckoo.MockManager.crashOnActorDefaultImplementationCall(\(literal))"
            } else if property.mentionsSelf {
                "Cuckoo.MockManager.crashOnSelfDefaultImplementationCall(\(literal))"
            } else {
                forwarding
            }
        }
        let crashOnSuperclass = "Cuckoo.MockManager.crashOnProtocolSuperclassCall()"

        var source = comments(of: property, documentation: property.documentation, context)
        source.append(contentsOf: attributes(of: property, at: property.accessibility, isolation: property.isolation))
        source.append("\(property.accessibility.spaced)\(modifiers(of: property, isStatic: property.isStatic))var \(escapeReservedKeywords(for: name)): \(property.type.description) {")
        source.append("    get \(effects){")
        source.append("        return \(tryAwait)\(manager).getter\(property.effects.isThrowing ? "Throws" : "")(")
        source.append("            \(literal),")
        source.append("            invoke: { (implementation: \(GeneratorHelper.genericSafeType(from: types.getter))) in \(tryAwait)implementation(\(isolated ? "self" : "()")) },")
        source.append("            superclassCall: \(context.isClass ? "\(tryAwait)super.\(name)" : crashOnSuperclass),")
        source.append("            defaultCall: \(defaultCall("\(tryAwait)__defaultImplStub.value.\(name)"))")
        source.append("        )")
        source.append("    }")
        if !property.isReadOnly {
            source.append("    set {")
            source.append("        \(manager).setter(")
            source.append("            \(literal),")
            source.append("            value: newValue,")
            source.append("            invoke: { (implementation: \(GeneratorHelper.genericSafeType(from: types.setter)), value) in implementation(\(isolated ? "self, value" : "value")) },")
            source.append("            superclassCall: \(context.isClass ? "super.\(name) = newValue" : crashOnSuperclass),")
            source.append("            defaultCall: \(defaultCall("__defaultImplStub.value.\(name) = newValue"))")
            source.append("        )")
            source.append("    }")
        }
        source.append("}")
        return lines(source)
    }

    private static func source(of initializer: Initializer, _ context: Context) -> String {
        let access = initializer.parent?.asProtocol?.accessibility ?? initializer.accessibility
        var source = comments(of: initializer, documentation: initializer.documentation, context)
        source.append(contentsOf: initializer.spiAttributes(at: access).map(\.description))
        source.append("\(access.spaced)required init\(initializer.signature.description) {}")
        return lines(source)
    }

    private static func source(of method: Method, _ context: Context) -> String {
        var source = comments(of: method, documentation: method.documentation, context)
        source.append(contentsOf: attributes(of: method, at: method.accessibility, isolation: method.isolation))
        if let execution = method.executionAttribute, !execution.isEmpty {
            source.append(execution)
        }
        source.append("\(method.accessibility.spaced)\(modifiers(of: method, isStatic: method.isStatic))func \(escapeReservedKeywords(for: method.name))\(method.signature.description) {")
        source.append(contentsOf: body(of: method, context).map { "    \($0)" })
        source.append("}")
        return lines(source)
    }

    private static func source(of subscriptDeclaration: Subscript, _ context: Context) -> String {
        var source = comments(of: subscriptDeclaration, documentation: subscriptDeclaration.documentation, context)
        source.append(contentsOf: attributes(of: subscriptDeclaration, at: subscriptDeclaration.accessibility, isolation: subscriptDeclaration.isolation))
        source.append("\(subscriptDeclaration.accessibility.spaced)\(modifiers(of: subscriptDeclaration, isStatic: subscriptDeclaration.isStatic))subscript\(subscriptDeclaration.signature) {")
        source.append("    get \(subscriptDeclaration.getterEffects){")
        source.append(contentsOf: body(of: subscriptDeclaration.mockedGetter, context).map { "        \($0)" })
        source.append("    }")
        if !subscriptDeclaration.isReadOnly {
            source.append("    set(\(subscriptDeclaration.newValueName)) {")
            source.append(contentsOf: body(of: subscriptDeclaration.mockedSetter, context).map { "        \($0)" })
            source.append("    }")
        }
        source.append("}")
        return lines(source)
    }

    /// The body of a mocked method or subscript accessor: it records the call and runs the stub.
    private static func body(of method: Method, _ context: Context) -> [String] {
        let literal = Fragment.literal(method.fullyQualifiedName)
        let throwTypeError = method.signature.throwType?.type ?? ""
        let hasTypedThrows = method.signature.throwType?.isTyped ?? false
        let tries = method.isThrowing ? " try" : ""
        let awaits = method.isAsync ? " await" : ""
        let callName = method.isThrowing ? (method.signature.throwType?.keyword ?? "").capitalizingFirstLetter : ""
        let arguments = method.implementationArguments
        let implementationEffects = method.throwsOnly ? "\(method.isAsync ? "async " : "")throws(\(throwTypeError)) " : ""
        let prologue = method.inoutPrologue.isEmpty ? "" : "\(method.inoutPrologue) "
        let call: String
        if hasTypedThrows {
            call = "do { return try \(method.isAsync ? "await " : "")implementation(\(arguments)) } catch { throw Cuckoo.MockManager.typedError(error, as: (\(throwTypeError)).self, member: \(literal)) }"
        } else {
            call = "\(method.inoutPrologue.isEmpty ? "" : "return ")\(method.isThrowing ? "try " : "")\(method.isAsync ? "await " : "")implementation(\(arguments))"
        }
        let superclassCall = if !context.isClass {
            "Cuckoo.MockManager.crashOnProtocolSuperclassCall()"
        } else if method.hasNoncopyableParams {
            "Cuckoo.MockManager.crashOnNoncopyableArgumentForward(\(literal))"
        } else {
            "\(method.isAsync ? "await " : "")\(method.superclassCall)"
        }
        let defaultCall = if context.isActor && !method.isStatic {
            "Cuckoo.MockManager.crashOnActorDefaultImplementationCall(\(literal))"
        } else if method.mentionsSelf && !method.isStatic {
            "Cuckoo.MockManager.crashOnSelfDefaultImplementationCall(\(literal))"
        } else if method.hasNoncopyableParams && !method.isStatic {
            "Cuckoo.MockManager.crashOnNoncopyableArgumentForward(\(literal))"
        } else {
            "\(method.isAsync && !method.isStatic ? "await " : "")\(method.defaultCall)"
        }

        var body = method.sendingParameterNames.map { "let __\($0) = Cuckoo.__SendingArgument(\($0))" }
        let opening = GeneratorHelper.openNestedClosure(for: method)
        body.append(contentsOf: opening)
        // The call sits inside the innermost closure or local function.
        let callIndentation = GeneratorHelper.indentation(opening.count)
        var recording: [String] = []
        recording.append("return\(tries)\(awaits) \(method.returnsSending ? "Cuckoo.__SendingArgument(" : "")\(manager(isStatic: method.isStatic)).call\(callName)(")
        recording.append("    \(literal),")
        recording.append("    parameters: (\(method.recordedParameters)),")
        recording.append("    escapingParameters: (\(method.escapingParameterNames)),")
        if method.throwsOnly {
            recording.append("    errorType: (\(throwTypeError)).self,")
        }
        recording.append("    invoke: { (implementation: \(GeneratorHelper.genericSafeType(from: method.stubTypes(resolvingSelfAs: nil).implementation)), arguments) \(implementationEffects)in \(prologue)\(call) },")
        recording.append("    superclassCall: \(superclassCall),")
        recording.append("    defaultCall: \(defaultCall)")
        recording.append(")\(method.returnsSending ? ").value" : "")")
        body.append(contentsOf: recording.map { callIndentation + $0 })
        body.append(contentsOf: GeneratorHelper.closeNestedClosure(for: method))
        return body
    }

    /// The source indented to the class's level. The formatter keeps the indentation a line has and indents the
    /// lines it adds, such as a closure's body, from it, so the members start where the mock's members sit.
    private static func classLevel(_ source: String) -> String {
        source.split(separator: "\n", omittingEmptySubsequences: false).map { $0.isEmpty ? "" : "    \($0)" }.joined(separator: "\n")
    }

    private static func lines(_ lines: [String]) -> String {
        lines.joined(separator: "\n")
    }
}

private extension String {
    var capitalizingFirstLetter: String {
        prefix(1).uppercased() + dropFirst()
    }
}
