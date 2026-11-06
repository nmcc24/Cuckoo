import SwiftSyntax

/// Builds `<Type>Stub`, the type whose members return default values and do nothing else.
///
/// Each member is parsed as it's built (see ``Fragment``), and the members are joined into the type's member block.
/// The file is laid out by `GeneratorHelper.format` afterwards, so the pieces only need the right lines, not the
/// right indentation.
enum NopImplStubBuilder {
    static func build(_ container: any ContainerToken) throws -> String {
        let name = "\(container.name)Stub"
        var members = Members()

        if container.declaresSelfTypealias {
            try members.append("\(container.accessibility.spaced)typealias \(SelfResolution.typealiasName) = \(name)", of: name)
        }
        if !container.isClass {
            for typealiasDeclaration in container.members.compactMap({ $0 as? Typealias }) {
                try members.append("\(container.accessibility.spaced)\(typealiasDeclaration.description)", of: "\(container.name).\(typealiasDeclaration.alias)")
            }
        }
        for property in container.mockedProperties {
            try members.append(property, source: source(of: property), of: "\(container.name).\(property.name)")
        }
        members.separate()
        for initializer in container.mockedInitializers {
            try members.append(initializer, source: source(of: initializer), of: "\(container.name).init\(initializer.signature.description)")
        }
        members.separate()
        for method in container.mockedMethods {
            try members.append(method, source: source(of: method), of: "\(container.name).\(method.name)")
        }
        for subscriptDeclaration in container.mockedSubscripts {
            members.separate()
            try members.append(subscriptDeclaration, source: source(of: subscriptDeclaration), of: "\(container.name)[]")
        }

        var headerLines = container.repeatedAttributes.map(\.description) + container.spiAttributes(at: container.accessibility).map(\.description)
        headerLines.append("\(container.accessibility.spaced)\(keyword(of: container)) \(name)\(container.genericParametersString): \(inheritance(of: container)) {\n}")
        let header = lines(headerLines)
        let declaration = try Fragment.declaration(header, of: name)
        if var classDeclaration = declaration.as(ClassDeclSyntax.self) {
            classDeclaration.memberBlock.members = members.list
            return classDeclaration.description
        } else if var actorDeclaration = declaration.as(ActorDeclSyntax.self) {
            actorDeclaration.memberBlock.members = members.list
            return actorDeclaration.description
        } else {
            throw FragmentError.unparsable(declaration: name, source: header)
        }
    }

    /// The stub's members, each on its own line, with a blank line where the layout calls for one.
    private struct Members {
        private(set) var list = MemberBlockItemListSyntax()
        private var separated = false

        /// The next member starts after a blank line.
        mutating func separate() {
            separated = true
        }

        mutating func append(_ source: String, of declaration: String) throws {
            var member = try Fragment.member(source, of: declaration)
            member.leadingTrivia = .newlines(separated ? 2 : 1)
            separated = false
            list.append(member)
        }

        /// A member without a `#if` around it is set off by a blank line; one with a `#if` follows on the next line.
        mutating func append(_ token: any HasAttributes, source: String, of declaration: String) throws {
            if !token.hasCompilationCondition {
                separate()
            }
            try append(conditional(token, source), of: declaration)
        }
    }

    private static func keyword(of container: any ContainerToken) -> String {
        guard let protocolDeclaration = container.asProtocol else { return "final class" }
        if protocolDeclaration.isActor { return "actor" }
        // The stub is explicitly `nonisolated`, so it doesn't take on the module's default isolation, unless it
        // takes on its declared superclass's.
        let isNonisolated = (protocolDeclaration.isolation == nil || protocolDeclaration.isolation == .nonisolated)
            && !protocolDeclaration.isSuperclassDeclared
        return isNonisolated ? "nonisolated final class" : "final class"
    }

    private static func inheritance(of container: any ContainerToken) -> String {
        let superclass = container.asProtocol?.superclass.flatMap { $0.isEmpty ? nil : "\($0), " } ?? ""
        let arguments = container.isClass ? container.genericArgumentsString : ""
        return "\(superclass)\(container.name)\(arguments)"
    }

    private static func source(of property: Variable) -> String {
        let effects = (property.effects.isAsync ? "async " : "") + (property.effects.isThrowing ? "throws " : "")
        let type = GeneratorHelper.removeClosureArgumentNames(for: GeneratorHelper.genericSafeType(from: property.type.description))
        let modifiers = modifiers(of: property, isStatic: property.isStatic)
        var source = attributes(of: property, at: property.accessibility, isolation: property.isolation)
        source.append("\(property.accessibility.spaced)\(modifiers)var \(property.name): \(property.type.description) {")
        source.append("    get \(effects){")
        source.append("        return DefaultValueRegistry.defaultValue(for: (\(type)).self)")
        source.append("    }")
        if !property.isReadOnly {
            source.append("    set {}")
        }
        source.append("}")
        return lines(source)
    }

    private static func source(of initializer: Initializer) -> String {
        let access = initializer.parent?.asProtocol?.accessibility ?? initializer.accessibility
        var source = initializer.spiAttributes(at: access).map(\.description)
        source.append("\(access.spaced)required init\(initializer.signature.description) {}")
        return lines(source)
    }

    private static func source(of method: Method) -> String {
        let type = GeneratorHelper.genericSafeType(from: method.defaultValueType)
        let modifiers = modifiers(of: method, isStatic: method.isStatic)
        var source = attributes(of: method, at: method.accessibility, isolation: method.isolation)
        if let execution = method.executionAttribute, !execution.isEmpty {
            source.append(execution)
        }
        source.append("\(method.accessibility.spaced)\(modifiers)func \(escapeReservedKeywords(for: method.name))\(method.signature.description) {")
        source.append("    return DefaultValueRegistry.defaultValue(for: (\(type)).self)")
        source.append("}")
        return lines(source)
    }

    private static func source(of subscriptDeclaration: Subscript) -> String {
        let effects = [subscriptDeclaration.isAsync ? "async" : nil, subscriptDeclaration.throwType?.description].compactMap { $0 }.map { "\($0) " }.joined()
        let type = GeneratorHelper.removeClosureArgumentNames(for: GeneratorHelper.genericSafeType(from: subscriptDeclaration.getter.defaultValueType))
        let modifiers = modifiers(of: subscriptDeclaration, isStatic: subscriptDeclaration.isStatic)
        var source = attributes(of: subscriptDeclaration, at: subscriptDeclaration.accessibility, isolation: subscriptDeclaration.isolation)
        source.append("\(subscriptDeclaration.accessibility.spaced)\(modifiers)subscript\(subscriptDeclaration.signature) {")
        source.append("    get \(effects){")
        source.append("        return DefaultValueRegistry.defaultValue(for: (\(type)).self)")
        source.append("    }")
        if !subscriptDeclaration.isReadOnly {
            source.append("    set {}")
        }
        source.append("}")
        return lines(source)
    }

    /// The attributes every copy of the member repeats, its `@_spi` attributes at its access level, and its isolation.
    private static func attributes(of member: any HasAttributes, at access: Accessibility, isolation: Isolation?) -> [String] {
        var attributes = member.repeatedAttributes.map(\.description) + member.spiAttributes(at: access).map(\.description)
        if let isolation = isolation?.sourceDescription, !isolation.isEmpty {
            attributes.append(isolation)
        }
        return attributes
    }

    /// A class's members override the superclass's.
    private static func modifiers(of member: any Token, isStatic: Bool) -> String {
        (member.parent?.isClass == true ? "override " : "") + (isStatic ? "static " : "")
    }

    /// The member inside its `#if`, if it has one.
    private static func conditional(_ member: any HasAttributes, _ source: String) -> String {
        member.hasCompilationCondition ? lines([member.compilationConditionCheck, source, "#endif"]) : source
    }

    private static func lines(_ lines: [String]) -> String {
        lines.joined(separator: "\n")
    }
}

private extension Accessibility {
    /// The keyword followed by a space, or nothing for the default access level.
    var spaced: String {
        sourceName.isEmpty ? "" : "\(sourceName) "
    }
}
