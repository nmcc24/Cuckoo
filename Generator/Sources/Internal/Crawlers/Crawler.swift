import Foundation
import SwiftSyntax
import SwiftParser

final class Crawler: SyntaxVisitor {
    /// - Parameter globalActors: The global actors declared in the module, besides `MainActor`. An attribute
    ///   with one of these names isolates the declaration; see ``declaredNames(in:)``.
    /// - Parameter noncopyableTypes: The `~Copyable` types declared in the module, whose arguments mocks record as
    ///   placeholders.
    static func crawl(url: URL, globalActors: Set<String> = [], noncopyableTypes: Set<String> = []) throws -> Crawler {
        let file = try String(contentsOf: url, encoding: .utf8)
        return crawl(source: file, url: url, globalActors: globalActors, noncopyableTypes: noncopyableTypes)
    }

    static func crawl(source: String, url: URL, globalActors: Set<String> = [], noncopyableTypes: Set<String> = []) -> Crawler {
        let syntaxTree = Parser.parse(source: source)
        #if DEBUG
        // Comment out the line above and uncomment the one below to test specific strings.
        // The `testString` is at the bottom of this file.
//        let syntaxTree = Parser.parse(source: testString)
        #endif
        let context = Context(
            url: url,
            locationConverter: SourceLocationConverter(fileName: url.path, tree: syntaxTree),
            globalActors: globalActors.union(["MainActor"]),
            noncopyableTypes: noncopyableTypes
        )
        let crawler = Self(container: nil, context: context)
        crawler.walk(syntaxTree)
        return crawler
    }

    /// State shared by the crawlers of one file. Each type's members are crawled by a crawler of their own.
    final class Context {
        let url: URL
        let locationConverter: SourceLocationConverter
        let globalActors: Set<String>
        let noncopyableTypes: Set<String>
        var diagnostics: [Diagnostic] = []

        init(url: URL, locationConverter: SourceLocationConverter, globalActors: Set<String>, noncopyableTypes: Set<String>) {
            self.url = url
            self.locationConverter = locationConverter
            self.globalActors = globalActors
            self.noncopyableTypes = noncopyableTypes
        }
    }

    /// A problem in the input that the generator works around instead of crashing.
    /// It's formatted like a compiler warning so Xcode and SwiftPM show it at the declaration.
    struct Diagnostic: CustomStringConvertible {
        let file: String
        let line: Int
        let column: Int
        let message: String

        var description: String {
            "\(file):\(line):\(column): warning: cuckoo: \(message)"
        }
    }

    var diagnostics: [Diagnostic] {
        context.diagnostics
    }

    var imports: [Import] = []
    var tokens: [any Token] = []
    /// The conditions of the `#if` clauses the crawler is currently inside.
    private var compilationConditions: [String] = []

    private var container: Reference<any Token>?

    /// The `#if` conditions around a type declared at the crawler's position: its enclosing types' conditions,
    /// and those of the `#if` clauses the crawler is inside.
    private var enclosingCompilationConditions: [String] {
        ((container?.value as? any HasEnclosingCompilationConditions)?.enclosingCompilationConditions ?? []) + compilationConditions
    }

    private let context: Context

    private init(container: Reference<any Token>?, context: Context) {
        self.container = container
        self.context = context

        super.init(viewMode: .sourceAccurate)
    }

    override func visit(_ node: ImportDeclSyntax) -> SyntaxVisitorContinueKind {
        let path = node.path.description
        let target: Import.Target = if let importKind = node.importKindSpecifier?.trimmed.text {
            // Component import.
            .component(kind: importKind, name: path)
        } else {
            // Target import.
            .library(name: path)
        }
        let isPublic = node.modifiers.contains { $0.name.tokenKind == .keyword(.public) }
        imports.append(Import(target: target, compilationConditions: compilationConditions, isPublic: isPublic))
        return .skipChildren
    }

    override func visit(_ node: ClassDeclSyntax) -> SyntaxVisitorContinueKind {
        debug(node)

        // Skip `final` classes.
        guard !node.modifiers.isFinal else { return .skipChildren }

        var token = ClassDeclaration(
            parent: container,
            attributes: attributes(from: node.attributes),
            accessibility: accessibility(from: node.modifiers) ?? (container as? any HasAccessibility)?.accessibility ?? .internal,
            name: node.name.filteredDescription,
            genericParameters: genericParameters(from: node.genericParameterClause?.parameters),
            genericRequirements: genericRequirements(from: node.genericWhereClause?.requirements),
            inheritedTypes: inheritedTypes(from: node.inheritanceClause?.inheritedTypes),
            members: [],
            enclosingCompilationConditions: enclosingCompilationConditions,
            isolation: isolation(attributes: node.attributes, modifiers: node.modifiers)
        )

        guard token.accessibility.isAccessible else { return .skipChildren }

        let crawler = Crawler(container: Reference(token), context: context)
        crawler.walk(members: node.memberBlock)
        token.members = crawler.tokens
        tokens.append(token)
        return .skipChildren
    }

    override func visit(_ node: ProtocolDeclSyntax) -> SyntaxVisitorContinueKind {
        debug(node)
        // `where Self: Base` binds conforming types as `: Base` does.
        let inheritedTypes = inheritedTypes(from: node.inheritanceClause?.inheritedTypes)
            + (node.genericWhereClause?.requirements ?? []).flatMap { requirement -> [String] in
                guard let conformance = requirement.requirement.as(ConformanceRequirementSyntax.self),
                      conformance.leftType.trimmedDescription == "Self" else { return [] }
                return self.inheritedTypes(from: conformance.rightType)
            }
        var token = ProtocolDeclaration(
            parent: container,
            attributes: attributes(from: node.attributes),
            accessibility: accessibility(from: node.modifiers) ?? (container as? any HasAccessibility)?.accessibility ?? .internal,
            name: node.name.filteredDescription,
            associatedTypes: associatedTypes(from: node.memberBlock.members),
            primaryAssociatedTypes: genericParameters(from: node.primaryAssociatedTypeClause?.primaryAssociatedTypes),
            genericRequirements: genericRequirements(from: node.genericWhereClause?.requirements),
            inheritedTypes: inheritedTypes,
            members: [],
            enclosingCompilationConditions: enclosingCompilationConditions,
            isolation: isolation(attributes: node.attributes, modifiers: node.modifiers)
        )

        guard token.accessibility.isAccessible else { return .skipChildren }

        let crawler = Crawler(container: Reference(token), context: context)
        crawler.walk(members: node.memberBlock)
        token.members = crawler.tokens
        tokens.append(token)
        return .skipChildren
    }

    // Enum mocking is not supported, this is used to parse nested classes.
    override func visit(_ node: EnumDeclSyntax) -> SyntaxVisitorContinueKind {
        debug(node)
        var token = NamespaceDeclaration(
            parent: container,
            attributes: attributes(from: node.attributes),
            accessibility: accessibility(from: node.modifiers) ?? (container as? any HasAccessibility)?.accessibility ?? .internal,
            name: node.name.filteredDescription,
            members: [],
            enclosingCompilationConditions: enclosingCompilationConditions
        )

        guard token.accessibility.isAccessible else { return .skipChildren }

        let crawler = Crawler(container: Reference(token), context: context)
        crawler.walk(members: node.memberBlock)
        token.members = crawler.tokens
        tokens.append(token)
        return .skipChildren
    }

    // Extension mocking is not supported, this is used to parse nested classes.
    override func visit(_ node: ExtensionDeclSyntax) -> SyntaxVisitorContinueKind {
        debug(node)
        var token = NamespaceDeclaration(
            parent: container,
            attributes: attributes(from: node.attributes),
            accessibility: accessibility(from: node.modifiers) ?? (container as? any HasAccessibility)?.accessibility ?? .internal,
            name: node.extendedType.filteredDescription,
            members: [],
            enclosingCompilationConditions: enclosingCompilationConditions
        )

        guard token.accessibility.isAccessible else { return .skipChildren }

        let crawler = Crawler(container: Reference(token), context: context)
        crawler.walk(members: node.memberBlock)
        token.members = crawler.tokens
        tokens.append(token)
        return .skipChildren
    }

    // Struct mocking is not supported, this is used to parse nested classes.
    override func visit(_ node: StructDeclSyntax) -> SyntaxVisitorContinueKind {
        debug(node)
        var token = NamespaceDeclaration(
            parent: container,
            attributes: attributes(from: node.attributes),
            accessibility: accessibility(from: node.modifiers) ?? (container as? any HasAccessibility)?.accessibility ?? .internal,
            name: node.name.filteredDescription,
            members: [],
            enclosingCompilationConditions: enclosingCompilationConditions
        )

        guard token.accessibility.isAccessible else { return .skipChildren }

        let crawler = Crawler(container: Reference(token), context: context)
        crawler.walk(members: node.memberBlock)
        token.members = crawler.tokens
        tokens.append(token)
        return .skipChildren
    }

    override func visit(_ node: VariableDeclSyntax) -> SyntaxVisitorContinueKind {
        guard let container, container.isMockable else { return .skipChildren }

        tokens.append(contentsOf: parse(node))
        return .skipChildren
    }

    override func visit(_ node: InitializerDeclSyntax) -> SyntaxVisitorContinueKind {
        guard let container, container.isMockable else { return .skipChildren }

        if let initializer = parse(node) {
            tokens.append(initializer)
        }
        return .skipChildren
    }

    override func visit(_ node: FunctionDeclSyntax) -> SyntaxVisitorContinueKind {
        guard let container, container.isMockable else { return .skipChildren }

        if let method = parse(node) {
            tokens.append(method)
        }
        return .skipChildren
    }

    override func visit(_ node: SubscriptDeclSyntax) -> SyntaxVisitorContinueKind {
        guard let container, container.isMockable else { return .skipChildren }

        if let item = parse(node) {
            tokens.append(item)
        }
        return .skipChildren
    }

    override func visit(_ node: IfConfigDeclSyntax) -> SyntaxVisitorContinueKind {
        // Each clause's members are crawled with the clause's full condition, so the
        // mock mirrors the `#if` instead of declaring members from every branch.
        var previousConditions: [String] = []
        for clause in node.clauses {
            let condition = clause.condition.map { "(\($0.trimmedDescription))" }
            compilationConditions.append(
                (previousConditions.map { "!\($0)" } + [condition].compactMap { $0 }).joined(separator: " && ")
            )
            switch clause.elements {
            case .decls(let members):
                walk(members)
            case .statements(let statements):
                walk(statements)
            default:
                break
            }
            compilationConditions.removeLast()
            condition.map { previousConditions.append($0) }
        }
        return .skipChildren
    }

    override func visit(_ node: TypeAliasDeclSyntax) -> SyntaxVisitorContinueKind {
        tokens.append(Typealias(syntax: node))
        return .skipChildren
    }

    private func walk(members: MemberBlockSyntax) {
        for member in members.members {
            walk(member)
        }
    }

    private func warn(_ node: some SyntaxProtocol, _ message: String) {
        let location = node.startLocation(converter: context.locationConverter, afterLeadingTrivia: true)
        context.diagnostics.append(
            Diagnostic(file: context.url.path, line: location.line, column: location.column, message: message)
        )
    }

        private func debug(_ node: any DeclSyntaxProtocol, additionalInfo: String? = nil) {
        let description: String
        switch node {
        case let node as ClassDeclSyntax:
            description = "class \(node.name.filteredDescription)"
        case let node as ProtocolDeclSyntax:
            description = "protocol \(node.name.filteredDescription)"
        case let node as StructDeclSyntax:
            description = "struct \(node.name.filteredDescription)"
        case let node as ExtensionDeclSyntax:
            description = "extension \(node.extendedType.filteredDescription)"
        case let node as EnumDeclSyntax:
            description = "enum \(node.name.filteredDescription)"
        default:
            description = "Unknown declaration \(node.filteredDescription)"
        }

        log(
            .verbose,
            message: [description, additionalInfo].compactMap { $0 }.joined(separator: " ")
        )
    }
}

// MARK: - Variable crawling.
extension Crawler {
    private func parse(_ variableGroup: VariableDeclSyntax) -> [Variable] {
        let isConstant = variableGroup.bindingSpecifier.tokenKind == .keyword(.let)

        guard let isStatic = staticness(of: variableGroup.modifiers) else { return [] }

        let attributes = attributes(from: variableGroup.attributes)
        // An unavailable member can't be overridden or called.
        guard !attributes.contains(where: \.isUnavailableEverywhere) else { return [] }

        var accessibility = Accessibility.internal
        var setterAccessibility: Accessibility?
        let modifiers = variableGroup.modifiers
        if !modifiers.isEmpty {
            for modifier in modifiers {
                let tokenKind = modifier.name.tokenKind

                guard let parsedAccessibility = Accessibility(tokenKind: tokenKind) else {
                    continue
                }

                if modifier.detail?.detail.tokenKind == .identifier("set") {
                    setterAccessibility = parsedAccessibility
                } else {
                    accessibility = parsedAccessibility
                }
            }
        }

        // Early return for private variable.
        guard accessibility.isAccessible else { return [] }

        // In `var x, y: Int`, `x` takes its type from the next annotated binding.
        var sharedType: TypeSyntax?
        let sharedTypes = variableGroup.bindings.reversed().map { binding -> TypeSyntax? in
            if let type = binding.typeAnnotation?.type {
                sharedType = type
            } else if binding.initializer != nil {
                sharedType = nil
            }
            return sharedType
        }.reversed()

        return zip(variableGroup.bindings, sharedTypes)
            .compactMap { variable(from: $0, declaredType: $1) }
            .map {
                Variable(
                    parent: container,
                    documentation: documentation(from: variableGroup.leadingTrivia),
                    attributes: attributes,
                    accessibility: accessibility,
                    setterAccessibility: $0.isReadOnly ? nil : setterAccessibility ?? (container as? any HasAccessibility)?.accessibility ?? .internal,
                    name: $0.identifier,
                    type: $0.type,
                    effects: $0.effects,
                    compilationConditions: compilationConditions,
                    isolation: isolation(attributes: variableGroup.attributes, modifiers: variableGroup.modifiers),
                    isConstant: isConstant,
                    isStatic: isStatic
                )
            }
    }

    private func variable(from binding: PatternBindingSyntax, declaredType: TypeSyntax?) -> VariablePart? {
        guard case .identifier(let identifier) = binding.pattern.as(IdentifierPatternSyntax.self)?.identifier.tokenKind else { return nil }

        let type: ComplexType
        if let explicitType = declaredType {
            type = ComplexType(syntax: explicitType)
        } else if let initializer = binding.initializer?.value.filteredDescription, let guessedType = TypeGuesser.guessType(from: initializer) {
            type = .type(guessedType)
        } else {
            warn(binding, "Can't infer the type of property '\(identifier)', so it isn't mocked. Add a type annotation to mock it.")
            return nil
        }

        let isReadOnly: Bool
        let effects: Variable.Effects
        switch binding.accessorBlock?.accessors {
        case .accessors(let accessors):
            let accessorsContainGet = accessors.contains { $0.accessorSpecifier.tokenKind == .keyword(.get) }
            let accessorsContainSet = accessors.contains { $0.accessorSpecifier.tokenKind == .keyword(.set) }
            isReadOnly = accessorsContainGet && !accessorsContainSet

            let getAccessor = accessors.first { $0.accessorSpecifier.tokenKind == .keyword(.get) }
            effects = Variable.Effects(
                isThrowing: getAccessor?.effectSpecifiers?.throwsClause != nil,
                isAsync: getAccessor?.effectSpecifiers?.asyncSpecifier?.isPresent == true
            )
        case .getter:
            isReadOnly = true
            effects = Variable.Effects()
        case nil:
            isReadOnly = false
            effects = Variable.Effects()
        }

        return VariablePart(
            identifier: identifier,
            type: type,
            isReadOnly: isReadOnly,
            effects: effects
        )
    }

    private struct VariablePart {
        var identifier: String
        var type: ComplexType
        var isReadOnly: Bool
        var effects: Variable.Effects
    }
}

extension Crawler {
    private func parse(_ initializer: InitializerDeclSyntax) -> Initializer? {
        let accessibility = initializer.modifiers.lazy.compactMap { Accessibility(tokenKind: $0.name.tokenKind) }.first ?? (container as? any HasAccessibility)?.accessibility ?? .internal

        guard accessibility.isAccessible else { return nil }

        let parameters = self.parameters(from: initializer.signature.parameterClause.parameters)

        return Initializer(
            parent: container,
            documentation: documentation(from: initializer.leadingTrivia),
            attributes: attributes(from: initializer.attributes),
            accessibility: accessibility,
            signature: Method.Signature(
                genericParameters: genericParameters(from: initializer.genericParameterClause?.parameters),
                parameters: parameters,
                asyncType: nil,
                throwType: ThrowType(syntax: initializer.signature.effectSpecifiers?.throwsClause),
                returnType: nil,
                whereConstraints: genericRequirements(from: initializer.genericWhereClause?.requirements)
            ),
            isRequired: initializer.modifiers.contains { $0.name == .keyword(.required) },
            isOptional: initializer.optionalMark?.isPresent == true,
            compilationConditions: compilationConditions
        )
    }
}

// MARK: - Subscript crawling.
extension Crawler {
    private func parse(_ node: SubscriptDeclSyntax) -> Subscript? {
        guard let isStatic = staticness(of: node.modifiers) else { return nil }

        let attributes = attributes(from: node.attributes)
        // An unavailable member can't be overridden or called.
        guard !attributes.contains(where: \.isUnavailableEverywhere) else { return nil }

        var accessibility = (container as? any HasAccessibility)?.accessibility ?? .internal
        var setterAccessibility: Accessibility?
        for modifier in node.modifiers {
            guard let parsedAccessibility = Accessibility(tokenKind: modifier.name.tokenKind) else { continue }
            if modifier.detail?.detail.tokenKind == .identifier("set") {
                setterAccessibility = parsedAccessibility
            } else {
                accessibility = parsedAccessibility
            }
        }
        guard accessibility.isAccessible else { return nil }

        let isReadOnly: Bool
        var getter: AccessorDeclSyntax?
        switch node.accessorBlock?.accessors {
        case .accessors(let accessors):
            getter = accessors.first { $0.accessorSpecifier.tokenKind == .keyword(.get) }
            isReadOnly = !accessors.contains { $0.accessorSpecifier.tokenKind == .keyword(.set) }
        case .getter, nil:
            isReadOnly = true
        }

        return Subscript(
            parent: container,
            documentation: documentation(from: node.leadingTrivia),
            attributes: attributes,
            accessibility: accessibility,
            setterAccessibility: isReadOnly ? nil : setterAccessibility ?? accessibility,
            genericParameters: genericParameters(from: node.genericParameterClause?.parameters),
            // A subscript's parameter has no argument label unless it states one.
            parameters: node.parameterClause.parameters.map { parameter in
                MethodParameter(
                    name: parameter.secondName == nil ? "_" : parameter.firstName.filteredDescription,
                    innerName: nil,
                    type: ComplexType(syntax: parameter.type)
                )
            },
            returnType: ComplexType(syntax: node.returnClause.type),
            whereConstraints: genericRequirements(from: node.genericWhereClause?.requirements),
            isAsync: getter?.effectSpecifiers?.asyncSpecifier?.isPresent == true,
            throwType: ThrowType(syntax: getter?.effectSpecifiers?.throwsClause),
            compilationConditions: compilationConditions,
            isolation: isolation(attributes: node.attributes, modifiers: node.modifiers),
            isStatic: isStatic
        )
    }
}

// MARK: - Method crawling.
extension Crawler {
    private func parse(_ method: FunctionDeclSyntax) -> Method? {
        guard let isStatic = staticness(of: method.modifiers) else { return nil }

        guard case .identifier(let identifier) = method.name.tokenKind else { return nil }

        let accessibility = method.modifiers.lazy.compactMap { Accessibility(tokenKind: $0.name.tokenKind) }.first ?? (container as? any HasAccessibility)?.accessibility ?? .internal

        guard accessibility.isAccessible else { return nil }

        let attributes = attributes(from: method.attributes)
        // An unavailable member can't be overridden or called.
        guard !attributes.contains(where: \.isUnavailableEverywhere) else { return nil }

        // Swift can't override a method with a parameter pack (it reports that the override overrides nothing), so a
        // class mock leaves such a method to the real implementation.
        let hasPack = method.genericParameterClause?.parameters.contains { $0.isPack } == true
        guard !(hasPack && container?.isClass == true) else { return nil }

        let parameters = self.parameters(
            from: method.signature.parameterClause.parameters,
            noncopyableGenerics: noncopyableGenericNames(
                in: method.genericParameterClause?.parameters,
                where: method.genericWhereClause?.requirements
            )
        )
        let returnType = method.signature.returnClause.flatMap { ComplexType(syntax: $0.type) }

        return Method(
            parent: container,
            documentation: documentation(from: method.leadingTrivia),
            attributes: attributes,
            accessibility: accessibility,
            name: identifier,
            signature: Method.Signature(
                genericParameters: genericParameters(from: method.genericParameterClause?.parameters),
                parameters: parameters,
                asyncType: method.signature.effectSpecifiers?.asyncSpecifier.flatMap { AsyncType(rawValue: $0.filteredDescription) },
                throwType: ThrowType(syntax: method.signature.effectSpecifiers?.throwsClause),
                returnType: returnType ?? ComplexType.type("Void"),
                whereConstraints: genericRequirements(from: method.genericWhereClause?.requirements)
            ),
            isOptional: method.modifiers.contains { $0.name.tokenKind == .keyword(.optional) },
            compilationConditions: compilationConditions,
            isolation: isolation(attributes: method.attributes, modifiers: method.modifiers),
            executionAttribute: executionAttribute(attributes: method.attributes, modifiers: method.modifiers),
            isStatic: isStatic
        )
    }
}

extension Crawler {
    /// - Parameter noncopyableGenerics: The member's generic parameters that may be `~Copyable`.
    private func parameters(from parameterList: FunctionParameterListSyntax, noncopyableGenerics: Set<String> = []) -> [MethodParameter] {
        parameterList.map { parameter in
            MethodParameter(
                name: parameter.firstName.filteredDescription,
                innerName: nil,
                type: ComplexType(syntax: parameter.type),
                isNoncopyable: isNoncopyable(parameter.type, generics: noncopyableGenerics)
            )
        }
    }

    /// Whether a parameter's type is one of the module's `~Copyable` types or a generic parameter that may be
    /// `~Copyable`, alone or optional. Other types that only mention one, such as a closure taking it, are copyable.
    private func isNoncopyable(_ type: TypeSyntax, generics: Set<String>) -> Bool {
        if let attributed = type.as(AttributedTypeSyntax.self) {
            return isNoncopyable(attributed.baseType, generics: generics)
        } else if let optional = type.as(OptionalTypeSyntax.self) {
            return isNoncopyable(optional.wrappedType, generics: generics)
        } else if let optional = type.as(ImplicitlyUnwrappedOptionalTypeSyntax.self) {
            return isNoncopyable(optional.wrappedType, generics: generics)
        } else if let identifier = type.as(IdentifierTypeSyntax.self) {
            return generics.contains(identifier.name.text) || context.noncopyableTypes.contains(identifier.name.text)
        } else if let member = type.as(MemberTypeSyntax.self) {
            return context.noncopyableTypes.contains(member.name.text)
        } else {
            return false
        }
    }

    /// The generic parameters that suppress `Copyable`, in their declaration (`T: ~Copyable`) or a `where` clause.
    private func noncopyableGenericNames(in parameters: GenericParameterListSyntax?, where requirements: GenericRequirementListSyntax?) -> Set<String> {
        let declared = (parameters ?? []).filter { parameter in
            parameter.inheritedType.map(Self.suppressesCopyable) ?? false
        }.map(\.name.text)
        let required = (requirements ?? []).compactMap { requirement -> String? in
            guard case .conformanceRequirement(let conformance) = requirement.requirement,
                  Self.suppressesCopyable(conformance.rightType) else { return nil }
            return conformance.leftType.trimmedDescription
        }
        return Set(declared + required)
    }

    /// Whether a constraint is or includes `~Copyable`.
    fileprivate static func suppressesCopyable(_ constraint: TypeSyntax) -> Bool {
        if let composition = constraint.as(CompositionTypeSyntax.self) {
            return composition.elements.contains { suppressesCopyable($0.type) }
        }
        return constraint.as(SuppressedTypeSyntax.self)?.type.trimmedDescription == "Copyable"
    }

    /// Whether a member is static (`static`, or `class`), or `nil` when the mock can't override it: a `final` member, or
    /// a class's `static` one, which is final too.
    private func staticness(of modifiers: DeclModifierListSyntax) -> Bool? {
        if modifiers.isFinal || (modifiers.isStatic && container?.isClass == true) {
            return nil
        }
        return modifiers.isStatic || modifiers.isClassMember
    }

    private func documentation(from trivia: Trivia) -> [String] {
        var docStrings: [String] = []
        for piece in trivia.pieces.reversed() {
            switch piece {
            case .docLineComment(let string):
                docStrings.insert(string.replacingOccurrences(of: "///", with: ""), at: 0)
            case .docBlockComment(let string):
                docStrings.insert(
                    contentsOf: string
                        .components(separatedBy: .newlines)
                        .map { $0.replacingOccurrences(of: "/**", with: "").replacingOccurrences(of: "*/", with: "") },
                    at: 0
                )
            case .spaces, .tabs:
                continue
            case .newlines(let count), .carriageReturns(let count), .carriageReturnLineFeeds(let count):
                // Only process docstrings directly attached to the declaration, a blank line ends them.
                if count > 1 {
                    return trimmed(docStrings)
                }
            default:
                return trimmed(docStrings)
            }
        }

        return trimmed(docStrings)
    }

    private func trimmed(_ docStrings: [String]) -> [String] {
        docStrings.compactMap { $0.trimmed.nilIfEmpty }
    }

    /// A global actor attribute, or the `nonisolated` modifier.
    private func isolation(attributes: AttributeListSyntax, modifiers: DeclModifierListSyntax) -> Isolation? {
        for case .attribute(let attribute) in attributes {
            if let name = attribute.attributeName.as(IdentifierTypeSyntax.self)?.name.text,
               attribute.arguments == nil,
               context.globalActors.contains(name) {
                return .globalActor(name)
            }
        }
        if modifiers.contains(where: { $0.name.tokenKind == .keyword(.nonisolated) && $0.detail == nil }) {
            return .nonisolated
        }
        return nil
    }

    /// `nonisolated(nonsending)` or `@concurrent`.
    private func executionAttribute(attributes: AttributeListSyntax, modifiers: DeclModifierListSyntax) -> String? {
        if let modifier = modifiers.first(where: { $0.name.tokenKind == .keyword(.nonisolated) && $0.detail != nil }) {
            return modifier.trimmedDescription
        }
        for case .attribute(let attribute) in attributes where attribute.attributeName.trimmedDescription == "concurrent" {
            return "@concurrent"
        }
        return nil
    }

    private func attributes(from attributeList: AttributeListSyntax?) -> [Attribute] {
        attributeList?.children(viewMode: .fixedUp)
            .compactMap { $0.as(AttributeSyntax.self).flatMap(attribute(from:)) }
            ?? []
    }

    private func attribute(from attribute: AttributeSyntax) -> Attribute? {
        if case .identifier(let identifier) = attribute.attributeName.as(IdentifierTypeSyntax.self)?.name.tokenKind {
            switch identifier {
            case "available":
                return .available(
                    arguments: attribute.arguments?.description
                        .split(separator: ",")
                        .map { String($0).trimmed } ?? []
                )
            // These will need some more work, not sure if worth the effort.
//            case "objc":
//                return .objc
//            case "objcMembers":
//                return .objcMembers
            default:
                log(.verbose, message: "Ignoring unsupported attribute '\(attribute.attributeName.trimmedDescription)'")
                return nil
            }
        } else {
            log(.verbose, message: "Ignoring unsupported attribute '\(attribute.attributeName.trimmedDescription)'")
            return nil
        }
    }

    private func accessibility(from modifierList: DeclModifierListSyntax?) -> Accessibility? {
        modifierList?.lazy.compactMap { Accessibility(tokenKind: $0.name.tokenKind) }.first
    }

    private func genericParameters(from genericParameterList: GenericParameterListSyntax?) -> [GenericParameter] {
        genericParameterList?.map { genericParameter in
            GenericParameter(
                name: genericParameter.name.filteredDescription,
                inheritedTypes: inheritedTypes(from: genericParameter.inheritedType?.trimmed),
                isPack: genericParameter.isPack
            )
        } ?? []
    }

    private func genericParameters(from primaryAssociatedTypeList: PrimaryAssociatedTypeListSyntax?) -> [GenericParameter] {
        primaryAssociatedTypeList?.compactMap { associatedType in
            return GenericParameter(
                name: associatedType.name.text,
                inheritedTypes: []
            )
        } ?? []
    }

    private func associatedTypes(from memberList: MemberBlockItemListSyntax) -> [GenericParameter] {
        memberList.compactMap { member in
            guard let associatedType = member.decl.as(AssociatedTypeDeclSyntax.self),
                  case .identifier(let identifier) = associatedType.name.tokenKind else { return nil }

            return GenericParameter(
                name: identifier,
                inheritedTypes: inheritedTypes(from: associatedType.inheritanceClause?.inheritedTypes)
            )
        }
    }

    private func genericRequirements(from genericRequirementList: GenericRequirementListSyntax?) -> [String] {
        genericRequirementList?.map { $0.requirement.filteredDescription } ?? []
    }

    private func inheritedTypes(from inheritedTypesList: InheritedTypeListSyntax?) -> [String] {
        inheritedTypesList?.flatMap { inheritedType -> [String] in
            inheritedTypes(from: inheritedType.type)
        } ?? []
    }

    private func inheritedTypes(from inheritedType: TypeSyntax?) -> [String] {
        guard let inheritedType else { return [] }
        if let compositeType = inheritedType.as(CompositionTypeSyntax.self) {
            return compositeType.elements.compactMap { $0.type.trimmedDescription }
        } else {
            return [inheritedType.trimmedDescription]
        }
    }
}

#if DEBUG
extension Crawler {
    private static let testString =
"""
public struct Prefs {}

public extension Prefs {
enum Key: String {
case blabla
}
}

// DUDE
@objcMembers
class Multi {
//    @available(iOS 42.0, *)
//    var gg: Bool = false

//    @available(*, renamed: "sameInstance(as:)")
//    let g: Bool
//    @available(*, renamed: "sameInstance(as:)")
//    private(set) var geg: Stool

    typealias MyInt = Int
    typealias MyIntGen<Generics> = Int<Generics>

    var didSet: Int = 3 {
        didSet {}
    }

    let constant = 3

    var gg: Dictionary<Int, String>
    var ggwp: Array<String>

    func gg(_ value: Any?, forKey: Prefs.Key) -> Jedna.Dva {}

    func generico<G: APIManager.GraphQLSomething>(plek: inout Enum.Gaga) {}

    func compositionalParameters(param1: any Equatable & Numeric, param2: OnlyLabelProtocol & Codable)

    @objc
    var hammo: Tpikulka!

    var heya: @escaping @convention(block) (_ jenda: Bool, _ dav: Krekr) async throws -> Void
    var heya: (@escaping @convention(block) (_ jenda: Bool, _ dav: Krekr) async throws -> Void)?

    /// Hola mi amor
    /// mamma mia
    var greg: Cruel {
        get {
            greg
        }
        set {
            greg = newValue
        }
    }

    #if DEBUG
    var pravda: Cool {
        thing
    }
    #elseif RELEASE
    var pravda: Cool {
        some
    }
    #endif

    /**
        This is everything you need to know.
    */
    func gaga<G: T>(plek: inout Gaga) {

    }
}

protocol Brek<Crack: Codable> {
    associatedtype plak: Encodable

    var asyncThrowsProperty: Int { get async throws }
    var mutableProperty: Int { get set }

    func drak()
}
"""
}
#endif

extension Crawler {
    /// The names a file declares that change how other files are mocked.
    struct DeclaredNames {
        /// The global actors (`@globalActor actor X`, or a class, struct or enum), so attributes naming them can be
        /// told apart from macros and property wrappers.
        var globalActors: Set<String> = []
        /// The `~Copyable` structs and enums, whose arguments mocks record as placeholders.
        var noncopyableTypes: Set<String> = []

        mutating func formUnion(_ other: DeclaredNames) {
            globalActors.formUnion(other.globalActors)
            noncopyableTypes.formUnion(other.noncopyableTypes)
        }
    }

    static func declaredNames(in source: String) -> DeclaredNames {
        let tree = Parser.parse(source: source)
        let collector = DeclaredNameCollector(viewMode: .sourceAccurate)
        collector.walk(tree)
        return collector.names
    }

    private final class DeclaredNameCollector: SyntaxVisitor {
        var names = DeclaredNames()

        private func collect(_ attributes: AttributeListSyntax, inheritance: InheritanceClauseSyntax?, name: TokenSyntax) {
            let isGlobalActor = attributes.contains { element in
                element.as(AttributeSyntax.self)?.attributeName.trimmedDescription == "globalActor"
            }
            if isGlobalActor {
                names.globalActors.insert(name.text)
            }
            if inheritance?.inheritedTypes.contains(where: { Crawler.suppressesCopyable($0.type) }) == true {
                names.noncopyableTypes.insert(name.text)
            }
        }

        override func visit(_ node: ActorDeclSyntax) -> SyntaxVisitorContinueKind {
            collect(node.attributes, inheritance: node.inheritanceClause, name: node.name)
            return .visitChildren
        }

        override func visit(_ node: ClassDeclSyntax) -> SyntaxVisitorContinueKind {
            collect(node.attributes, inheritance: node.inheritanceClause, name: node.name)
            return .visitChildren
        }

        override func visit(_ node: StructDeclSyntax) -> SyntaxVisitorContinueKind {
            collect(node.attributes, inheritance: node.inheritanceClause, name: node.name)
            return .visitChildren
        }

        override func visit(_ node: EnumDeclSyntax) -> SyntaxVisitorContinueKind {
            collect(node.attributes, inheritance: node.inheritanceClause, name: node.name)
            return .visitChildren
        }
    }
}

extension GenericParameterSyntax {
    /// Whether this is a parameter pack (`each T`). swift-syntax 601 replaced `eachKeyword` with `specifier`,
    /// which also holds the `let` of a value generic.
    var isPack: Bool {
        #if canImport(SwiftSyntax601)
        specifier?.tokenKind == .keyword(.each)
        #else
        eachKeyword != nil
        #endif
    }
}
