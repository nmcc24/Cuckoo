#if canImport(FoundationEssentials)
import FoundationEssentials
#else
import Foundation
#endif
import SwiftSyntax
import SwiftParser

final class Crawler: SyntaxVisitor {
    /// - Parameter globalActors: The global actors declared in the module, besides `MainActor`. An attribute
    ///   with one of these names isolates the declaration; see ``declaredNames(in:)``.
    /// - Parameter noncopyableTypes: The `~Copyable` types declared in the module, whose arguments mocks record as
    ///   placeholders.
    static func crawl(
        source: String,
        url: URL,
        globalActors: Set<String> = [],
        noncopyableTypes: Set<String> = [],
        closureTypealiases: [String: String] = [:],
        nonPublicTypes: Set<String> = [],
        genericTypes: Set<String> = [],
        qualifiedGenericTypes: Set<String> = [],
        uncheckedSendableTypes: Set<String> = [],
        protocolsAndClasses: Set<String>? = nil,
        compositionTypealiases: [String: [String]] = [:],
        actors: Set<String> = [],
        privateNames: Set<String> = [],
        nominalTypes: Set<String> = [],
        defaultIsolation: Isolation? = nil
    ) -> Crawler {
        let syntaxTree = Parser.parse(source: source)
        // This file's own actors and private names count even when the caller scanned no other files.
        let local = declaredNames(in: source)
        let context = Context(
            url: url,
            locationConverter: SourceLocationConverter(fileName: url.path, tree: syntaxTree),
            globalActors: globalActors.union(["MainActor"]),
            noncopyableTypes: noncopyableTypes,
            closureTypealiases: closureTypealiases,
            nonPublicTypes: nonPublicTypes,
            genericTypes: genericTypes,
            qualifiedGenericTypes: qualifiedGenericTypes.union(local.qualifiedGenericTypes),
            uncheckedSendableTypes: uncheckedSendableTypes.union(local.uncheckedSendableTypes),
            protocolsAndClasses: protocolsAndClasses,
            compositionTypealiases: compositionTypealiases,
            actors: actors.union(local.actors),
            privateNames: privateNames.union(local.privateNames),
            nominalTypes: nominalTypes.union(local.nominalTypes),
            defaultIsolation: defaultIsolation
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
        /// The module's typealiases of function types, by qualified name, to the function type, generic ones with
        /// their generic parameters first.
        let closureTypealiases: [String: String]
        /// The module's types declared without `public` or `open`.
        let nonPublicTypes: Set<String>
        /// The module's generic structs, classes and enums.
        let genericTypes: Set<String>
        /// The generic types, by qualified name.
        let qualifiedGenericTypes: Set<String>
        /// The types an extension declares `@unchecked Sendable`, by qualified name.
        let uncheckedSendableTypes: Set<String>
        /// The module's protocols and classes, or nil when unknown, as in a crawl of one file for a test.
        let protocolsAndClasses: Set<String>?
        /// The module's typealiases of protocol compositions.
        let compositionTypealiases: [String: [String]]
        /// The module's actors, so an extension of one is known to be an actor's.
        let actors: Set<String>
        /// The names the module declares `private` or `fileprivate`, which a mock in another file can't use.
        let privateNames: Set<String>
        /// The names of the module's structs, classes, enums, actors and protocols.
        let nominalTypes: Set<String>
        /// The module's `defaultIsolation` option: the isolation of the protocols and classes that state none.
        let defaultIsolation: Isolation?
        var diagnostics: [Diagnostic] = []
        /// The protocols left unmocked because of a requirement a mock can't implement, so the ones refining them
        /// can be left out too.
        var unmockedProtocols: Set<String> = []

        init(
            url: URL,
            locationConverter: SourceLocationConverter,
            globalActors: Set<String>,
            noncopyableTypes: Set<String>,
            closureTypealiases: [String: String] = [:],
            nonPublicTypes: Set<String> = [],
            genericTypes: Set<String> = [],
            qualifiedGenericTypes: Set<String> = [],
            uncheckedSendableTypes: Set<String> = [],
            protocolsAndClasses: Set<String>? = nil,
            compositionTypealiases: [String: [String]] = [:],
            actors: Set<String> = [],
            privateNames: Set<String> = [],
            nominalTypes: Set<String> = [],
            defaultIsolation: Isolation?
        ) {
            self.url = url
            self.locationConverter = locationConverter
            self.globalActors = globalActors
            self.noncopyableTypes = noncopyableTypes
            self.closureTypealiases = closureTypealiases
            self.nonPublicTypes = nonPublicTypes
            self.genericTypes = genericTypes
            self.qualifiedGenericTypes = qualifiedGenericTypes
            self.uncheckedSendableTypes = uncheckedSendableTypes
            self.protocolsAndClasses = protocolsAndClasses
            self.compositionTypealiases = compositionTypealiases
            self.actors = actors
            self.privateNames = privateNames
            self.nominalTypes = nominalTypes
            self.defaultIsolation = defaultIsolation
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

    var unmockedProtocols: Set<String> {
        context.unmockedProtocols
    }

    var imports: [Import] = []
    var tokens: [any Token] = []
    /// Members of a class that its mock can't override, each with the reason, which the mock states in a comment.
    var unmockedMembers: [String] = []
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
        let path = node.path.trimmedDescription
        let target: Import.Target = if let importKind = node.importKindSpecifier?.trimmed.text {
            // Component import.
            .component(kind: importKind, name: path)
        } else {
            // Target import.
            .library(name: path)
        }
        let isPublic = node.modifiers.contains { $0.name.tokenKind == .keyword(.public) }
        let spiGroups = attributes(from: node.attributes).compactMap(\.spiGroup)
        imports.append(Import(target: target, compilationConditions: compilationConditions, isPublic: isPublic, spiGroups: spiGroups))
        return .skipChildren
    }

    override func visit(_ node: ClassDeclSyntax) -> SyntaxVisitorContinueKind {
        debug(node)

        // Skip `final` classes.
        guard !node.modifiers.isFinal else { return .skipChildren }

        var token = ClassDeclaration(
            parent: container,
            attributes: attributes(from: node.attributes),
            accessibility: accessibility(from: node.modifiers) ?? nestedTypeDefaultAccessibility,
            name: node.name.filteredDescription,
            genericParameters: genericParameters(from: node.genericParameterClause?.parameters),
            genericRequirements: genericRequirements(from: node.genericWhereClause?.requirements),
            inheritedTypes: inheritedTypes(from: node.inheritanceClause?.inheritedTypes),
            members: [],
            enclosingCompilationConditions: enclosingCompilationConditions,
            isolation: isolation(attributes: node.attributes, modifiers: node.modifiers) ?? defaultIsolationOfNestedType
        )

        guard token.accessibility.isAccessible else { return .skipChildren }

        let crawler = Crawler(container: Reference(token), context: context)
        crawler.walk(members: node.memberBlock)
        token.members = crawler.tokens
        token.unmockedMembers = crawler.unmockedMembers
        token.unknownAttributes = unknownAttributes(node.attributes, declaration: token.name)
        token.isUncheckedSendable = node.inheritanceClause?.inheritedTypes.contains(where: { Self.isUncheckedSendable($0.type) }) == true
            || context.uncheckedSendableTypes.contains(DeclaredNameCollector.qualifiedName(of: token.name, at: Syntax(node)))
        // A public mock's overrides must be public (with a `@testable` import too), and a public override can't name
        // a non-public type. A public class with such members gets an internal mock, as `@testable` users need anyway.
        if token.accessibility >= .public, let type = token.members.lazy.compactMap({ self.nonPublicType(usedBy: $0) }).first {
            token.accessibility = .internal
            token.internalMockReason = type
        }
        tokens.append(token)
        return .skipChildren
    }

    override func visit(_ node: ProtocolDeclSyntax) -> SyntaxVisitorContinueKind {
        debug(node)
        // `where Self: Base` binds conforming types as `: Base` does.
        // A parent's function typealias arguments are found as Swift finds them from the inheritance clause: in the
        // scopes around the protocol, not among its own members.
        let inheritedTypes = expandingCompositions(inheritedTypes(from: node.inheritanceClause?.inheritedTypes, expandingFrom: Syntax(node)))
            + (node.genericWhereClause?.requirements ?? []).flatMap { requirement -> [String] in
                guard let conformance = requirement.requirement.as(ConformanceRequirementSyntax.self),
                      conformance.leftType.trimmedDescription == "Self" else { return [] }
                return self.inheritedTypes(from: conformance.rightType, expandingFrom: Syntax(conformance.rightType))
            }
        var token = ProtocolDeclaration(
            parent: container,
            attributes: attributes(from: node.attributes),
            accessibility: accessibility(from: node.modifiers) ?? nestedTypeDefaultAccessibility,
            name: node.name.filteredDescription,
            associatedTypes: associatedTypes(from: node.memberBlock.members),
            primaryAssociatedTypes: genericParameters(from: node.primaryAssociatedTypeClause?.primaryAssociatedTypes),
            // An associated type's own `where` clause constrains the protocol as one on the protocol does.
            genericRequirements: genericRequirements(from: node.genericWhereClause?.requirements)
                + node.memberBlock.members.flatMap { member in
                    genericRequirements(from: member.decl.as(AssociatedTypeDeclSyntax.self)?.genericWhereClause?.requirements)
                },
            inheritedTypes: inheritedTypes,
            members: [],
            enclosingCompilationConditions: enclosingCompilationConditions,
            isolation: isolation(attributes: node.attributes, modifiers: node.modifiers)
        )
        token.unknownAttributes = unknownAttributes(node.attributes, declaration: token.name)
        token.parentsOutsideSources = parentsOutsideSources(of: token)
        // An actor-constrained protocol is isolated to its conforming actor, never to the default.
        if token.isolation == nil, !token.isActor, let defaultIsolation = defaultIsolationOfNestedType {
            token.isolation = defaultIsolation
            token.isIsolationDefault = true
        }

        guard token.accessibility.isAccessible else { return .skipChildren }

        let crawler = Crawler(container: Reference(token), context: context)
        crawler.walk(members: node.memberBlock)
        // A protocol's mock has to implement every requirement, so one it can't return leaves the protocol unmocked.
        guard crawler.unmockedMembers.isEmpty else {
            warn(node, "'\(token.name)' isn't mocked: " + crawler.unmockedMembers.joined(separator: " "))
            context.unmockedProtocols.insert(token.name)
            return .skipChildren
        }
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
            accessibility: accessibility(from: node.modifiers) ?? nestedTypeDefaultAccessibility,
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
            accessibility: accessibility(from: node.modifiers) ?? nestedTypeDefaultAccessibility,
            name: node.extendedType.filteredDescription,
            members: [],
            enclosingCompilationConditions: enclosingCompilationConditions,
            isExtension: true
        )

        guard token.accessibility.isAccessible else { return .skipChildren }

        let crawler = Crawler(container: Reference(token), context: context)
        crawler.walk(members: node.memberBlock)
        token.members = crawler.tokens
        tokens.append(token)
        return .skipChildren
    }

    // Actors are final, so they aren't mocked; this parses the types nested in them, which would otherwise be
    // taken for top-level types.
    override func visit(_ node: ActorDeclSyntax) -> SyntaxVisitorContinueKind {
        debug(node)
        var token = NamespaceDeclaration(
            parent: container,
            attributes: attributes(from: node.attributes),
            accessibility: accessibility(from: node.modifiers) ?? nestedTypeDefaultAccessibility,
            name: node.name.filteredDescription,
            members: [],
            enclosingCompilationConditions: enclosingCompilationConditions,
            isActor: true
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
            accessibility: accessibility(from: node.modifiers) ?? nestedTypeDefaultAccessibility,
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

        // An override has to repeat the property's type, which an opaque `some` type can't be.
        if container.isClass, let opaqueBinding = node.bindings.first(where: { $0.typeAnnotation.map { Self.containsOpaqueType($0.type) } ?? false }) {
            unmockedMembers.append("'\(opaqueBinding.pattern.trimmedDescription)' has the opaque type '\(opaqueBinding.typeAnnotation?.type.trimmedDescription ?? "")', which an override can't repeat.")
            return .skipChildren
        }
        for binding in node.bindings {
            if let type = binding.typeAnnotation?.type, skipsUnreturnable(binding, member: binding.pattern.trimmedDescription, type: type) {
                return .skipChildren
            }
        }
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

        if container.isClass, let returnType = node.signature.returnClause?.type, Self.containsOpaqueType(returnType) {
            unmockedMembers.append("'\(node.name.trimmedDescription)\(node.signature.parameterClause.trimmedDescription)' returns the opaque type '\(returnType.trimmedDescription)', which an override can't repeat.")
            return .skipChildren
        }
        let generics = noncopyableGenericNames(in: node.genericParameterClause?.parameters, where: node.genericWhereClause?.requirements)
        if let returnType = node.signature.returnClause?.type,
           skipsUnreturnable(node, member: "\(node.name.trimmedDescription)\(node.signature.parameterClause.trimmedDescription)", type: returnType, generics: generics) {
            return .skipChildren
        }
        if let method = parse(node) {
            tokens.append(method)
        }
        return .skipChildren
    }

    override func visit(_ node: SubscriptDeclSyntax) -> SyntaxVisitorContinueKind {
        guard let container, container.isMockable else { return .skipChildren }

        if container.isClass, Self.containsOpaqueType(node.returnClause.type) {
            unmockedMembers.append("'subscript\(node.parameterClause.trimmedDescription)' returns the opaque type '\(node.returnClause.type.trimmedDescription)', which an override can't repeat.")
            return .skipChildren
        }
        let subscriptGenerics = noncopyableGenericNames(in: node.genericParameterClause?.parameters, where: node.genericWhereClause?.requirements)
        if skipsUnreturnable(node, member: "subscript\(node.parameterClause.trimmedDescription)", type: node.returnClause.type, generics: subscriptGenerics) {
            return .skipChildren
        }

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

    /// Parents without requirements a mock would have to implement, which it can inherit without knowing them.
    static let parentsWithoutRequirements: Set<String> = [
        "Sendable", "SendableMetatype", "AnyObject", "Actor", "AnyActor", "Error", "Copyable", "Escapable",
        "NSObjectProtocol", "~Copyable", "~Escapable",
    ]

    /// A typealias of a protocol composition, `AB` for `A & B`, stands for its protocols.
    private func expandingCompositions(_ types: [String], depth: Int = 0) -> [String] {
        types.flatMap { type -> [String] in
            // A qualified typealias, `NS.Both`, is found by its last component.
            let name = String(type.split(separator: ".").last ?? Substring(type))
            guard depth < 8, let composed = context.compositionTypealiases[name] else { return [type] }
            return expandingCompositions(composed, depth: depth + 1)
        }
    }

    /// The mock implements the requirements of the protocols in the sources, so one inheriting a protocol declared
    /// elsewhere, such as `Equatable`, may not conform. Its mock says so in a comment, where a "doesn't conform" error
    /// points; a build warning would be wrong whenever a default implementation covers the requirements.
    private func parentsOutsideSources(of token: ProtocolDeclaration) -> [String] {
        guard let known = context.protocolsAndClasses else { return [] }
        return token.inheritedTypes.filter { parent in
            let name = String(parent.withoutGenericArguments.split(separator: ".").last ?? "")
            return !known.contains(name) && !Self.parentsWithoutRequirements.contains(name)
                && context.compositionTypealiases[name] == nil
        }
    }

    /// The module's default isolation for a type declared here: none inside an actor, whose nested types Swift
    /// leaves nonisolated.
    private var defaultIsolationOfNestedType: Isolation? {
        var ancestor = container?.value
        while let current = ancestor {
            if let namespace = current as? NamespaceDeclaration,
               namespace.isActor || (namespace.isExtension && Self.namesAnActor(namespace.name, actors: context.actors, types: context.nominalTypes)) {
                return nil
            }
            ancestor = current.parent?.value
        }
        return context.defaultIsolation
    }

    /// Whether an extension's type, `Worker`, `Outer.Worker` or `App.Outer.Worker`, is one of the module's actors,
    /// which are known by qualified name. A leading module name is left out only when it names no type.
    static func namesAnActor(_ name: String, actors: Set<String>, types: Set<String>) -> Bool {
        func normalized(_ name: String) -> String {
            var components = name.split(separator: ".").map(String.init)
            if components.count > 1, !types.contains(components[0]) {
                components.removeFirst()
            }
            return components.joined(separator: ".")
        }
        return actors.contains { normalized($0) == normalized(name) }
    }

    /// The first of the module's non-public types a non-public member names in its signature, if any.
    private func nonPublicType(usedBy member: any Token) -> String? {
        guard !context.nonPublicTypes.isEmpty,
              let accessible = member as? any HasAccessibility, accessible.accessibility < .public else { return nil }
        let signature: String
        switch member {
        case let variable as Variable:
            signature = variable.type.description
        case let method as Method:
            signature = method.signature.parameters.map(\.type.description).joined(separator: ",") + "," + (method.returnType?.description ?? "")
        case let subscriptDeclaration as Subscript:
            signature = subscriptDeclaration.parameters.map(\.type.description).joined(separator: ",") + "," + subscriptDeclaration.returnType.description
        default:
            return nil
        }
        let identifiers = signature.split(whereSeparator: { !($0.isLetter || $0.isNumber || $0 == "_") })
        return identifiers.lazy.map(String.init).first { context.nonPublicTypes.contains($0) }
    }

    /// A parameter's type, with a typealias of a function type replaced by the function type: a non-escaping closure
    /// written through a typealias, `(_ handler: Handler)`, needs the same handling as one written out.
    private func parameterType(_ type: TypeSyntax) -> ComplexType {
        // `sending Handler`, `@Sendable Handler`: the typealias under the specifiers and attributes. An `inout` one
        // stays as written: the closure a variable holds is escaping, so the mock records it as it is.
        if let attributed = type.as(AttributedTypeSyntax.self),
           !attributed.specifiers.contains(where: { $0.trimmedDescription == "inout" }),
           let expanded = expandedClosureTypealias(attributed.baseType) {
            let prefix = (attributed.specifiers.map(\.trimmedDescription) + attributed.attributes.map(\.trimmedDescription)).joined(separator: " ")
            var parser = Parser("\(prefix) \(expanded.trimmedDescription)")
            return ComplexType(syntax: TypeSyntax.parse(from: &parser))
        }
        if let expanded = expandedClosureTypealias(type) {
            return ComplexType(syntax: expanded)
        }
        return ComplexType(syntax: type)
    }

    /// The function type a typealias written as `type` stands for, qualified to read the same in the mock, or nil.
    /// - Parameter lookup: Where an unqualified name is looked up from, `type` itself by default.
    private func expandedClosureTypealias(_ type: TypeSyntax, lookingUpFrom lookup: Syntax? = nil) -> TypeSyntax? {
        if let identifier = type.as(IdentifierTypeSyntax.self),
           let (functionType, scope) = closureTypealias(named: identifier.name.text, from: lookup ?? Syntax(type)) {
            return instance(of: functionType, in: scope, with: identifier.genericArgumentClause)
        }
        // A qualified one, `Uploader.Completion`, by its full name.
        if let member = type.as(MemberTypeSyntax.self),
           let functionType = context.closureTypealiases[member.with(\.genericArgumentClause, nil).trimmedDescription] {
            let scope = member.baseType.trimmedDescription.split(separator: ".").map(String.init)
            return instance(of: functionType, in: scope, with: member.genericArgumentClause)
        }
        return nil
    }

    /// A typealias's function type, written in `scope`, for the generic arguments it's used with: qualified first,
    /// since its names are the scope's, then given the arguments, which are written where it's used.
    private func instance(of functionType: String, in scope: [String], with arguments: GenericArgumentClauseSyntax?) -> TypeSyntax? {
        let (parameters, body) = Self.genericParameters(of: functionType)
        let qualified = qualifying(body, in: scope, excluding: Set(parameters)).trimmedDescription
        guard let instance = Self.instantiating(qualified, parameters: parameters, with: arguments) else { return nil }
        var parser = Parser(instance)
        return TypeSyntax.parse(from: &parser)
    }

    /// The generic parameters a stored function type starts with, `<T> (T) -> Void`, and the function type after them.
    private static func genericParameters(of functionType: String) -> (parameters: [String], body: String) {
        guard functionType.hasPrefix("<"), let end = functionType.firstIndex(of: ">") else { return ([], functionType) }
        let parameters = functionType[functionType.index(after: functionType.startIndex)..<end]
            .split(separator: ",").map { String($0.trimmedSpaces) }
        return (parameters, String(functionType[functionType.index(after: end)...]).trimmedSpaces)
    }

    /// A generic typealias's function type for the generic arguments it's used with, `Handler<Int>` for `<T>` and
    /// `(T) -> Void` being `(Int) -> Void`, or nil when they don't match its generic parameters.
    private static func instantiating(_ functionType: String, parameters: [String], with arguments: GenericArgumentClauseSyntax?) -> String? {
        guard !parameters.isEmpty else { return arguments == nil ? functionType : nil }
        guard let arguments, arguments.arguments.count == parameters.count else { return nil }
        // An argument such as `any P` or `() -> Void` is parenthesized, so it keeps its meaning in any position.
        let substitutions = Dictionary(uniqueKeysWithValues: zip(parameters, arguments.arguments.map { argument in
            let type = argument.argument.as(TypeSyntax.self)
            let needsParentheses = type.map {
                $0.is(FunctionTypeSyntax.self) || $0.is(CompositionTypeSyntax.self) || $0.is(SomeOrAnyTypeSyntax.self) || $0.is(AttributedTypeSyntax.self)
            } ?? true
            return needsParentheses ? "(\(argument.argument.trimmedDescription))" : argument.argument.trimmedDescription
        }))
        final class Substitution: SyntaxRewriter {
            let substitutions: [String: String]
            init(_ substitutions: [String: String]) {
                self.substitutions = substitutions
            }
            override func visit(_ node: IdentifierTypeSyntax) -> TypeSyntax {
                guard node.genericArgumentClause == nil, let argument = substitutions[node.name.text] else {
                    return super.visit(node)
                }
                var parser = Parser(argument)
                return TypeSyntax.parse(from: &parser).with(\.leadingTrivia, node.leadingTrivia).with(\.trailingTrivia, node.trailingTrivia)
            }
        }
        var parser = Parser(functionType)
        return Substitution(substitutions).rewrite(TypeSyntax.parse(from: &parser)).trimmedDescription
    }

    /// `functionType`, written in `scope`, with each type it names from that scope written qualified, so it reads
    /// the same where the mock uses it: `(Receipt) -> Void` in `Uploader` is `(Uploader.Receipt) -> Void`. The
    /// `excluded` names, a generic typealias's parameters, stay as written. A generic type in the scope can't be
    /// named without its arguments, so what's nested in it stays unqualified: a class mock, its subclass, finds it.
    private func qualifying(_ functionType: String, in scope: [String], excluding excluded: Set<String> = []) -> TypeSyntax {
        var parser = Parser(functionType)
        let type = TypeSyntax.parse(from: &parser)
        guard !scope.isEmpty else { return type }
        final class Qualifier: SyntaxRewriter {
            let scope: [String]
            let types: Set<String>
            let genericTypes: Set<String>
            let excluded: Set<String>
            init(scope: [String], types: Set<String>, genericTypes: Set<String>, excluded: Set<String>) {
                self.scope = scope
                self.types = types
                self.genericTypes = genericTypes
                self.excluded = excluded
            }
            override func visit(_ node: IdentifierTypeSyntax) -> TypeSyntax {
                guard !excluded.contains(node.name.text) else { return super.visit(node) }
                for length in stride(from: scope.count, through: 1, by: -1) {
                    let qualified = (scope.prefix(length) + [node.name.text]).joined(separator: ".")
                    if types.contains(qualified) {
                        // The innermost declaration is the one meant, even when it can't be written qualified.
                        let isInGenericType = (1...length).contains { genericTypes.contains(scope.prefix($0).joined(separator: ".")) }
                        guard !isInGenericType else { return super.visit(node) }
                        // `Box<Receipt>`: the arguments name types of the same scope too.
                        let arguments = node.genericArgumentClause.map { rewrite(Syntax($0)).trimmedDescription } ?? ""
                        var parser = Parser(qualified + arguments)
                        return TypeSyntax.parse(from: &parser).with(\.leadingTrivia, node.leadingTrivia).with(\.trailingTrivia, node.trailingTrivia)
                    }
                }
                return super.visit(node)
            }
        }
        return Qualifier(scope: scope, types: context.nominalTypes, genericTypes: context.qualifiedGenericTypes, excluded: excluded)
            .rewrite(type).cast(TypeSyntax.self)
    }

    /// The function type `name` stands for where `node` uses it, found as Swift finds it: a generic parameter,
    /// an associated type or a typealias of an enclosing declaration comes first, then the module's top-level
    /// typealiases. A typealias Swift finds elsewhere, in another extension of the type, a superclass or a parent
    /// protocol, is taken when it's the module's only one of that name. Nil when `name` isn't a typealias of a
    /// function type there; otherwise the function type with the qualified name of the type that declares it,
    /// whose names it uses.
    private func closureTypealias(named name: String, from node: Syntax) -> (type: String, scope: [String])? {
        func components(_ name: String) -> [String] {
            name.split(separator: ".").map(String.init)
        }
        switch closureTypealiasInScope(named: name, from: node) {
        case .shadowed:
            return nil
        case .found(let functionType, let scope):
            return functionType.map { ($0, components(scope)) }
        case .notFound:
            // Declared in another extension of an enclosing type, or in one of its superclasses or parent protocols.
            for scope in memberLookupScopes(from: node) {
                if let functionType = context.closureTypealiases["\(scope).\(name)"] {
                    return (functionType, components(scope))
                }
            }
            if let topLevel = context.closureTypealiases[name] {
                return (topLevel, [])
            }
            // Only when nothing else in the module has the name, which a type of its own would then be.
            guard !context.nominalTypes.contains(name) else { return nil }
            let nested = context.closureTypealiases.filter { $0.key.hasSuffix("." + name) }
            guard Set(nested.values).count == 1, let (key, functionType) = nested.first else { return nil }
            // Spelled the same in several types, it's qualified only when they're all the same type.
            return (functionType, nested.count == 1 ? Array(components(key).dropLast()) : [])
        }
    }

    /// The qualified names a member lookup from `node` also searches, innermost first: each enclosing type,
    /// written as its declaration or extension names it, and the types it inherits from, as written.
    private func memberLookupScopes(from node: Syntax) -> [String] {
        var scopes: [String] = []
        var ancestor = node.parent
        while let current = ancestor {
            if let group = current.asProtocol((any DeclGroupSyntax).self) {
                if let extensionDeclaration = current.as(ExtensionDeclSyntax.self) {
                    scopes.append(DeclaredNameCollector.qualifiedName(of: extensionDeclaration.extendedType.trimmedDescription, at: current))
                } else if let named = current.asProtocol((any NamedDeclSyntax).self) {
                    scopes.append(DeclaredNameCollector.qualifiedName(of: named.name.text, at: current))
                }
                scopes += group.inheritanceClause?.inheritedTypes.map { $0.type.trimmedDescription } ?? []
            }
            ancestor = current.parent
        }
        return scopes
    }

    private enum ScopedTypealias {
        case shadowed
        /// The function type, if the typealias stands for one, and the qualified name of the type declaring it.
        case found(String?, scope: String)
        case notFound
    }

    private func closureTypealiasInScope(named name: String, from node: Syntax) -> ScopedTypealias {
        func declares(_ clause: GenericParameterClauseSyntax?) -> Bool {
            clause?.parameters.contains { $0.name.text == name } == true
        }
        var ancestor = node.parent
        while let current = ancestor {
            if let function = current.as(FunctionDeclSyntax.self), declares(function.genericParameterClause) { return .shadowed }
            if let initializer = current.as(InitializerDeclSyntax.self), declares(initializer.genericParameterClause) { return .shadowed }
            if let subscriptDeclaration = current.as(SubscriptDeclSyntax.self), declares(subscriptDeclaration.genericParameterClause) { return .shadowed }
            if let group = current.asProtocol((any DeclGroupSyntax).self) {
                if let generic = current.asProtocol((any WithGenericParametersSyntax).self), declares(generic.genericParameterClause) {
                    return .shadowed
                }
                if let protocolDeclaration = current.as(ProtocolDeclSyntax.self),
                   protocolDeclaration.primaryAssociatedTypeClause?.primaryAssociatedTypes.contains(where: { $0.name.text == name }) == true {
                    return .shadowed
                }
                for member in group.memberBlock.members {
                    if let associated = member.decl.as(AssociatedTypeDeclSyntax.self), associated.name.text == name {
                        return .shadowed
                    }
                    if let nested = member.decl.asProtocol((any NamedDeclSyntax).self), nested.name.text == name,
                       member.decl.asProtocol((any DeclGroupSyntax).self) != nil {
                        return .shadowed
                    }
                    if let alias = member.decl.as(TypeAliasDeclSyntax.self), alias.name.text == name {
                        return .found(Self.functionType(of: alias), scope: Self.qualifiedScope(of: current))
                    }
                }
            }
            ancestor = current.parent
        }
        return .notFound
    }

    /// The qualified name of a type declaration or of the type an extension extends.
    private static func qualifiedScope(of group: Syntax) -> String {
        if let extensionDeclaration = group.as(ExtensionDeclSyntax.self) {
            return DeclaredNameCollector.qualifiedName(of: extensionDeclaration.extendedType.trimmedDescription, at: group)
        }
        if let named = group.asProtocol((any NamedDeclSyntax).self) {
            return DeclaredNameCollector.qualifiedName(of: named.name.text, at: group)
        }
        return ""
    }

    /// The function type a typealias stands for, or nil when it's another type. A generic typealias's starts with
    /// its generic parameters' names, `<T> (T) -> Void`, which ``instantiating(_:with:)`` replaces.
    static func functionType(of alias: TypeAliasDeclSyntax) -> String? {
        var type = alias.initializer.value
        if let attributed = type.as(AttributedTypeSyntax.self), attributed.specifiers.isEmpty {
            type = attributed.baseType
        }
        guard type.is(FunctionTypeSyntax.self) else { return nil }
        guard let generics = alias.genericParameterClause else { return alias.initializer.value.trimmedDescription }
        // A pack or a value generic can't be substituted by name.
        guard generics.parameters.allSatisfy({ $0.specifier == nil }) else { return nil }
        return "<\(generics.parameters.map(\.name.text).joined(separator: ", "))> \(alias.initializer.value.trimmedDescription)"
    }

    /// Whether `type` contains an opaque `some` type anywhere, as in `some View` or `[some View]`.
    static func containsOpaqueType(_ type: TypeSyntax) -> Bool {
        final class Finder: SyntaxVisitor {
            var found = false
            override func visit(_ node: SomeOrAnyTypeSyntax) -> SyntaxVisitorContinueKind {
                if node.someOrAnySpecifier.tokenKind == .keyword(.some) {
                    found = true
                }
                return found ? .skipChildren : .visitChildren
            }
        }
        let finder = Finder(viewMode: .sourceAccurate)
        finder.walk(type)
        return finder.found
    }

    /// Whether an inherited type is `@unchecked Sendable`.
    static func isUncheckedSendable(_ type: TypeSyntax) -> Bool {
        guard let attributed = type.as(AttributedTypeSyntax.self),
              attributed.attributes.contains(where: { $0.trimmedDescription == "@unchecked" }) else { return false }
        let base = attributed.baseType.trimmedDescription
        return base == "Sendable" || base == "Swift.Sendable"
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
                    setterAccessibility: $0.isReadOnly ? nil : setterAccessibility ?? .internal,
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
        } else if let initializer = binding.initializer?.value, let guessedType = TypeGuesser.guessType(from: initializer, genericTypes: context.genericTypes) {
            type = .type(guessedType)
        } else {
            warn(binding, "Can't infer the type of property '\(identifier)', so it isn't mocked. Add a type annotation to mock it.")
            return nil
        }

        let isReadOnly: Bool
        let effects: Variable.Effects
        switch binding.accessorBlock?.accessors {
        case .accessors(let accessors):
            // Settable with a setter, or as a stored property with observers; read-only with only reading accessors,
            // `get`, `_read` or `unsafeAddress`.
            let writing: Set = [
                "set", "_modify", "modify", "mutate", "unsafeMutableAddress", "mutableAddressWithOwner",
                "mutableAddressWithNativeOwner", "willSet", "didSet",
            ]
            isReadOnly = !accessors.contains { writing.contains($0.accessorSpecifier.text) }

            let getAccessor = accessors.first { $0.accessorSpecifier.tokenKind == .keyword(.get) }
            effects = Variable.Effects(
                isThrowing: getAccessor?.effectSpecifiers?.throwsClause.map { !ThrowType.isNever($0) } ?? false,
                isAsync: getAccessor?.effectSpecifiers?.asyncSpecifier?.isPresent == true,
                typedError: getAccessor?.effectSpecifiers?.throwsClause.flatMap { ThrowType.isNever($0) ? nil : $0.type?.trimmedDescription }
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
        let accessibility = initializer.modifiers.lazy.compactMap { Accessibility(tokenKind: $0.name.tokenKind) }.first ?? .internal

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

        var accessibility = Accessibility.internal
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
                let type = parameterType(parameter.type)
                let isVariadic = parameter.ellipsis?.isPresent == true
                return MethodParameter(
                    name: parameter.secondName == nil ? "_" : parameter.firstName.filteredDescription,
                    innerName: nil,
                    type: isVariadic ? .type("[\(type)]") : type,
                    variadicElement: isVariadic ? type : nil,
                    defaultValue: parameter.defaultValue.flatMap { mockableDefaultValue($0, of: parameter.type) }
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

        let identifier: String
        let operatorFixity: Method.OperatorFixity?
        switch method.name.tokenKind {
        case .identifier(let name):
            identifier = name
            operatorFixity = nil
        case .binaryOperator(let name), .prefixOperator(let name), .postfixOperator(let name):
            // A class's own operators are `static`, so final: the mock can't override them, and keeps the real ones.
            guard container?.isClass != true else { return nil }
            identifier = name
            let modifiers = method.modifiers.map(\.name.tokenKind)
            operatorFixity = if modifiers.contains(.keyword(.prefix)) {
                .prefix
            } else if modifiers.contains(.keyword(.postfix)) {
                .postfix
            } else {
                .infix
            }
        default:
            return nil
        }

        let accessibility = method.modifiers.lazy.compactMap { Accessibility(tokenKind: $0.name.tokenKind) }.first ?? .internal

        guard accessibility.isAccessible else { return nil }

        let attributes = attributes(from: method.attributes)
        // An unavailable member can't be overridden or called.
        guard !attributes.contains(where: \.isUnavailableEverywhere) else { return nil }

        // Swift can't override a method with a parameter pack (it reports that the override overrides nothing), so a
        // class mock leaves such a method to the real implementation.
        let hasPack = method.genericParameterClause?.parameters.contains { $0.isPack } == true
        guard !(hasPack && container?.isClass == true) else { return nil }

        var parameters = self.parameters(
            from: method.signature.parameterClause.parameters,
            noncopyableGenerics: noncopyableGenericNames(
                in: method.genericParameterClause?.parameters,
                where: method.genericWhereClause?.requirements
            )
        )
        if operatorFixity != nil {
            // An operator's parameters have no argument labels.
            for index in parameters.indices {
                parameters[index].name = "_"
            }
        }
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
            isStatic: isStatic,
            operatorFixity: operatorFixity
        )
    }
}

extension Crawler {
    /// - Parameter noncopyableGenerics: The member's generic parameters that may be `~Copyable`.
    private func parameters(from parameterList: FunctionParameterListSyntax, noncopyableGenerics: Set<String> = []) -> [MethodParameter] {
        parameterList.map { parameter in
            // A variadic parameter, `Int...`, is an array inside the function: the mock records and matches that.
            let type = parameterType(parameter.type)
            let isVariadic = parameter.ellipsis?.isPresent == true
            return MethodParameter(
                name: parameter.firstName.filteredDescription,
                innerName: nil,
                type: isVariadic ? .type("[\(type)]") : type,
                isNoncopyable: isNoncopyable(parameter.type, generics: noncopyableGenerics),
                variadicElement: isVariadic ? type : nil,
                defaultValue: parameter.defaultValue.flatMap { mockableDefaultValue($0, of: parameter.type) }
            )
        }
    }

    /// A default argument the mock can repeat: not one that names a `private` or `fileprivate` declaration, which
    /// the mock, in another file, can't see. Without its default, a call through the mock's own type passes the
    /// argument, as it did before Cuckoo kept defaults. A name the module declares private anywhere counts, whatever
    /// else shares it, since leaving a default out is always safe; argument labels don't.
    private func mockableDefaultValue(_ clause: InitializerClauseSyntax, of parameterType: TypeSyntax) -> String? {
        guard !context.privateNames.isEmpty else { return clause.value.trimmedDescription }
        final class References: SyntaxVisitor {
            var names: [String] = []
            override func visit(_ node: DeclReferenceExprSyntax) -> SyntaxVisitorContinueKind {
                names.append(node.baseName.text)
                return .visitChildren
            }
            override func visit(_ node: IdentifierTypeSyntax) -> SyntaxVisitorContinueKind {
                names.append(node.name.text)
                return .visitChildren
            }
            override func visit(_ node: MemberTypeSyntax) -> SyntaxVisitorContinueKind {
                names.append(node.name.text)
                return .visitChildren
            }
            /// The type `.init(…)` with no type written creates when it's the whole default: the parameter's.
            let parameterTypeName: String?
            let root: SyntaxIdentifier
            init(parameterType: TypeSyntax, root: SyntaxIdentifier) {
                self.root = root
                var type = parameterType
                while true {
                    if let attributed = type.as(AttributedTypeSyntax.self) {
                        type = attributed.baseType
                    } else if let optional = type.as(OptionalTypeSyntax.self) {
                        type = optional.wrappedType
                    } else if let unwrapped = type.as(ImplicitlyUnwrappedOptionalTypeSyntax.self) {
                        type = unwrapped.wrappedType
                    } else {
                        break
                    }
                }
                parameterTypeName = type.as(IdentifierTypeSyntax.self)?.name.text ?? type.as(MemberTypeSyntax.self)?.name.text
                super.init(viewMode: .sourceAccurate)
            }
            /// The name a `.init(…)` of an unknown type goes in as.
            static let unknownInitializer = ".init("
            override func visit(_ node: MemberAccessExprSyntax) -> SyntaxVisitorContinueKind {
                // `Token.init(secret:)` without a call, a function value that needs the initializer as much as a
                // call does; a call's `.init` is read with its call.
                guard node.declName.baseName.tokenKind == .keyword(.`init`), node.parent?.as(FunctionCallExprSyntax.self)?.calledExpression.id != node.id else {
                    return .visitChildren
                }
                var base = node.base
                if let specialized = base?.as(GenericSpecializationExprSyntax.self) {
                    base = specialized.expression
                }
                if let reference = base?.as(DeclReferenceExprSyntax.self) {
                    names.append(DeclaredNames.privateInitializerName(of: reference.baseName.text))
                } else if let member = base?.as(MemberAccessExprSyntax.self) {
                    names.append(DeclaredNames.privateInitializerName(of: member.declName.baseName.text))
                } else if base == nil {
                    names.append(Self.unknownInitializer)
                }
                return .visitChildren
            }
            override func visit(_ node: FunctionCallExprSyntax) -> SyntaxVisitorContinueKind {
                // `Token(…)`, `Module.Token(…)`, `Box<Int>(…)`, `Token.init(…)` and `.init(…)` call an initializer
                // of `Token`, or of the parameter's type.
                var callee = node.calledExpression
                if let member = callee.as(MemberAccessExprSyntax.self), member.declName.baseName.tokenKind == .keyword(.`init`) {
                    guard let base = member.base else {
                        // Elsewhere, in `[.init(…)]` or an argument, its type isn't known here.
                        let type = node.id == root ? parameterTypeName : nil
                        names.append(type.map(DeclaredNames.privateInitializerName(of:)) ?? Self.unknownInitializer)
                        return .visitChildren
                    }
                    callee = base
                }
                // `Token.self.init(…)`.
                if let member = callee.as(MemberAccessExprSyntax.self), member.declName.baseName.tokenKind == .keyword(.self),
                   let base = member.base {
                    callee = base
                }
                if let specialized = callee.as(GenericSpecializationExprSyntax.self) {
                    callee = specialized.expression
                }
                if let reference = callee.as(DeclReferenceExprSyntax.self) {
                    names.append(DeclaredNames.privateInitializerName(of: reference.baseName.text))
                } else if let member = callee.as(MemberAccessExprSyntax.self) {
                    names.append(DeclaredNames.privateInitializerName(of: member.declName.baseName.text))
                }
                return .visitChildren
            }
        }
        let references = References(parameterType: parameterType, root: clause.value.id)
        references.walk(clause.value)
        // A `.init(…)` whose type isn't known may be any type's that has a private initializer.
        if references.names.contains(References.unknownInitializer),
           context.privateNames.contains(where: { $0.hasSuffix("(") }) {
            return nil
        }
        return references.names.contains(where: context.privateNames.contains) ? nil : clause.value.trimmedDescription
    }

    /// Skips a member whose type is `~Copyable` or `~Escapable`, which a mock can't return: it can't keep a stubbed
    /// value to return it again. A class's mock leaves the member to the real implementation, with a warning; a
    /// protocol isn't mocked at all, as its mock can't leave out a requirement.
    private func skipsUnreturnable(_ node: some SyntaxProtocol, member: String, type: TypeSyntax, generics: Set<String> = []) -> Bool {
        let generics = generics.union(enclosingNoncopyableGenerics(of: Syntax(node)))
        let kind = if isNoncopyable(type, generics: generics) {
            "~Copyable"
        } else if isNonescapable(type) {
            "~Escapable"
        } else {
            nil as String?
        }
        guard let kind else { return false }
        let reason = "'\(member)' returns the \(kind) type '\(type.trimmedDescription)', which a mock can't return."
        unmockedMembers.append(reason)
        if container?.isClass == true {
            warn(node, reason + " The mock keeps the real implementation.")
        }
        return true
    }

    /// The `~Copyable` generic parameters of the types enclosing `node`, such as `T` in `class Pool<T: ~Copyable>`.
    private func enclosingNoncopyableGenerics(of node: Syntax) -> Set<String> {
        var names: Set<String> = []
        var ancestor = node.parent
        while let current = ancestor {
            if let generic = current.asProtocol((any WithGenericParametersSyntax).self) {
                let requirements = current.as(ClassDeclSyntax.self)?.genericWhereClause?.requirements
                    ?? current.as(StructDeclSyntax.self)?.genericWhereClause?.requirements
                    ?? current.as(EnumDeclSyntax.self)?.genericWhereClause?.requirements
                    ?? current.as(ActorDeclSyntax.self)?.genericWhereClause?.requirements
                names.formUnion(noncopyableGenericNames(in: generic.genericParameterClause?.parameters, where: requirements))
            }
            ancestor = current.parent
        }
        return names
    }

    /// The standard library's `~Escapable` types.
    private static let nonescapableTypes: Set = ["Span", "MutableSpan", "RawSpan", "MutableRawSpan", "OutputSpan", "OutputRawSpan", "UTF8Span"]

    /// Whether a type is one of the standard library's `~Escapable` types, alone or optional.
    private func isNonescapable(_ type: TypeSyntax) -> Bool {
        if let attributed = type.as(AttributedTypeSyntax.self) {
            return isNonescapable(attributed.baseType)
        } else if let optional = type.as(OptionalTypeSyntax.self) {
            return isNonescapable(optional.wrappedType)
        } else if let identifier = type.as(IdentifierTypeSyntax.self) {
            // A type of the module with the same name, such as a tracing `Span`, is the one meant.
            return Self.nonescapableTypes.contains(identifier.name.text) && resolvedTypeName(identifier.name.text, from: Syntax(type)) == nil
        } else if let member = type.as(MemberTypeSyntax.self) {
            return member.baseType.trimmedDescription == "Swift" && Self.nonescapableTypes.contains(member.name.text)
        }
        return false
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
            if generics.contains(identifier.name.text) {
                return true
            }
            // `Optional<Ticket>`, written out.
            if identifier.name.text == "Optional", let wrapped = identifier.genericArgumentClause?.arguments.first?.argument.as(TypeSyntax.self) {
                return isNoncopyable(wrapped, generics: generics)
            }
            return resolvedTypeName(identifier.name.text, from: Syntax(type)).map(context.noncopyableTypes.contains) ?? false
        } else if let member = type.as(MemberTypeSyntax.self) {
            return context.noncopyableTypes.contains(member.with(\.genericArgumentClause, nil).trimmedDescription)
        } else {
            return false
        }
    }

    /// The qualified name of the module's type that `name`, written at `node`, names, as Swift finds it: in the
    /// innermost enclosing scope that declares it, else at the top level. `nil` for a type the module doesn't declare.
    private func resolvedTypeName(_ name: String, from node: Syntax) -> String? {
        (memberLookupScopes(from: node).map { "\($0).\(name)" } + [name]).first { context.nominalTypes.contains($0) }
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
                docStrings.insert(string.replacing("///", with: ""), at: 0)
            case .docBlockComment(let string):
                docStrings.insert(
                    contentsOf: string
                        .split(omittingEmptySubsequences: false, whereSeparator: \.isNewline)
                        .map { String($0.replacing("/**", with: "").replacing("*/", with: "")) },
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
            // `@MainActor` or a qualified `@_Concurrency.MainActor`, matched by its last component.
            if let name = Self.attributeTypeName(attribute),
               attribute.arguments == nil,
               context.globalActors.contains(name) {
                return .globalActor(attribute.attributeName.trimmedDescription)
            }
        }
        if modifiers.contains(where: { $0.name.tokenKind == .keyword(.nonisolated) && $0.detail == nil }) {
            return .nonisolated
        }
        return nil
    }

    /// An attribute's type name, the last component of a qualified one: `MainActor` for `@_Concurrency.MainActor`.
    private static func attributeTypeName(_ attribute: AttributeSyntax) -> String? {
        if let identifier = attribute.attributeName.as(IdentifierTypeSyntax.self) {
            identifier.name.text
        } else if let member = attribute.attributeName.as(MemberTypeSyntax.self) {
            member.name.text
        } else {
            nil
        }
    }

    /// Attributes a mocked type may carry that are known not to be global actors: Swift's own and common macros.
    private static let knownTypeAttributes: Set<String> = [
        "Observable", "Model", "Suite", "Test", "MainActor", "Sendable", "GlobalActor", "ObservationIgnored",
        "ObservationTracked", "Entry", "Previewable", "Testable", "UIApplicationMain", "NSApplicationMain",
    ]

    /// The capitalised attributes without arguments on a protocol or class that the generator can't classify: a
    /// global actor declared in another module, which the mock would need, looks like a macro or a property wrapper.
    /// A name ending in `Actor` almost certainly is one, so it warns, pointing at the `globalActors` option; any other
    /// gets a comment in the mock, where a resulting isolation error would point.
    private func unknownAttributes(_ attributes: AttributeListSyntax, declaration: String) -> [String] {
        var unknown: [String] = []
        for case .attribute(let attribute) in attributes where attribute.arguments == nil {
            guard let name = Self.attributeTypeName(attribute), name.first?.isUppercase == true,
                  !context.globalActors.contains(name), !Self.knownTypeAttributes.contains(name) else { continue }
            let written = attribute.attributeName.trimmedDescription
            if name.hasSuffix("Actor") {
                warn(attribute, "'\(declaration)' is marked @\(written), which isn't a global actor declared in the mocked sources, so its mock isn't isolated to it. If @\(written) is a global actor from another module, add it to the module's `globalActors` in the Cuckoofile.")
            }
            unknown.append(written)
        }
        return unknown
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
            case "_spi":
                guard let group = attribute.arguments?.trimmedDescription, !group.isEmpty else { return nil }
                return .spi(group: group)
            default:
                log(.verbose, message: "Ignoring unsupported attribute '\(attribute.attributeName.trimmedDescription)'")
                return nil
            }
        } else {
            log(.verbose, message: "Ignoring unsupported attribute '\(attribute.attributeName.trimmedDescription)'")
            return nil
        }
    }

    /// The access level of a type declared with no access modifier: an extension's carries over to what it declares,
    /// a type's doesn't.
    private var nestedTypeDefaultAccessibility: Accessibility {
        guard let namespace = container?.value as? NamespaceDeclaration, namespace.isExtension else { return .internal }
        return namespace.accessibility
    }

    private func accessibility(from modifierList: DeclModifierListSyntax?) -> Accessibility? {
        modifierList?.lazy.compactMap { Accessibility(tokenKind: $0.name.tokenKind) }.first
    }

    private func genericParameters(from genericParameterList: GenericParameterListSyntax?) -> [GenericParameter] {
        genericParameterList?.map { genericParameter in
            GenericParameter(
                name: genericParameter.name.filteredDescription,
                inheritedTypes: inheritedTypes(from: genericParameter.inheritedType?.trimmed),
                kind: genericParameter.kind
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

    /// The protocol's associated types, those inside `#if` too: the mock's generic parameters can't depend on a
    /// condition, so it takes them all, and in a build where the condition is false they're just unused.
    private func associatedTypes(from memberList: MemberBlockItemListSyntax, condition: String? = nil) -> [GenericParameter] {
        memberList.flatMap { member -> [GenericParameter] in
            guard let conditional = member.decl.as(IfConfigDeclSyntax.self) else {
                return associatedType(member).map { parameter in
                    var parameter = parameter
                    parameter.condition = condition
                    return [parameter]
                } ?? []
            }
            // Each clause holds when its own condition does and none before it did.
            var previous: [String] = []
            let clauses = conditional.clauses.map { clause -> [GenericParameter] in
                let own = clause.condition.map { "(\($0.trimmedDescription))" }
                let clauseCondition = ([condition].compactMap { $0 } + previous.map { "!\($0)" } + [own].compactMap { $0 })
                    .joined(separator: " && ")
                if let own {
                    previous.append(own)
                }
                guard case .decls(let members)? = clause.elements else { return [] }
                return associatedTypes(from: members, condition: clauseCondition)
            }
            // One declared in every clause, `#else` included, exists whatever the conditions; in some of them, under
            // any of their conditions. It takes every clause's constraints, which the mock's generic parameter
            // meets in each build.
            let hasElse = conditional.clauses.last?.condition == nil
            return clauses.joined().map(\.name).uniquing().map { name in
                let declarations = clauses.joined().filter { $0.name == name }
                let isInEveryClause = hasElse && clauses.allSatisfy { $0.contains { $0.name == name } }
                let conditions = declarations.compactMap(\.condition).uniquing()
                return GenericParameter(
                    name: name,
                    inheritedTypes: declarations.flatMap(\.inheritedTypes).uniquing(),
                    kind: declarations[0].kind,
                    condition: isInEveryClause || declarations.contains { $0.condition == nil }
                        ? condition
                        : conditions.count == 1 ? conditions[0] : conditions.map { "(\($0))" }.joined(separator: " || ")
                )
            }
        }
        .reduce(into: [GenericParameter]()) { unique, parameter in
            if !unique.contains(where: { $0.name == parameter.name }) {
                unique.append(parameter)
            }
        }
    }

    private func associatedType(_ member: MemberBlockItemSyntax) -> GenericParameter? {
        guard let associatedType = member.decl.as(AssociatedTypeDeclSyntax.self),
              case .identifier(let identifier) = associatedType.name.tokenKind else { return nil }
        return GenericParameter(
            name: identifier,
            inheritedTypes: inheritedTypes(from: associatedType.inheritanceClause?.inheritedTypes)
        )
    }

    private func genericRequirements(from genericRequirementList: GenericRequirementListSyntax?) -> [String] {
        genericRequirementList?.map { $0.requirement.filteredDescription } ?? []
    }

    /// - Parameter lookup: For a protocol's parents, where their function typealias arguments are looked up from;
    ///   `nil` leaves every type as written.
    private func inheritedTypes(from inheritedTypesList: InheritedTypeListSyntax?, expandingFrom lookup: Syntax? = nil) -> [String] {
        inheritedTypesList?.flatMap { inheritedType -> [String] in
            inheritedTypes(from: inheritedType.type, expandingFrom: lookup)
        } ?? []
    }

    private func inheritedTypes(from inheritedType: TypeSyntax?, expandingFrom lookup: Syntax? = nil) -> [String] {
        guard let inheritedType else { return [] }
        func written(_ type: TypeSyntax) -> String {
            lookup.map { expandingFunctionTypealiasArguments(type, lookingUpFrom: $0) } ?? type.trimmedDescription
        }
        if let compositeType = inheritedType.as(CompositionTypeSyntax.self) {
            return compositeType.elements.compactMap { written($0.type) }
        } else {
            return [written(inheritedType)]
        }
    }

    /// A parent as written, with each generic argument that names a function typealias written as its function
    /// type, `Transforming<Formatting>` as `Transforming<(Int) -> String>`: the associated type it binds then makes
    /// the mock's parameters closures, which it has to make escaping. The typealias is found as a parameter's is.
    private func expandingFunctionTypealiasArguments(_ type: TypeSyntax, lookingUpFrom lookup: Syntax) -> String {
        let clause = type.as(IdentifierTypeSyntax.self)?.genericArgumentClause ?? type.as(MemberTypeSyntax.self)?.genericArgumentClause
        guard let clause else { return type.trimmedDescription }
        var changed = false
        let arguments = clause.arguments.map { argument -> String in
            if let argumentType = argument.argument.as(TypeSyntax.self), let expanded = expandedClosureTypealias(argumentType, lookingUpFrom: lookup) {
                changed = true
                return expanded.trimmedDescription
            }
            return argument.argument.trimmedDescription
        }
        guard changed else { return type.trimmedDescription }
        let base = type.as(IdentifierTypeSyntax.self).map { $0.name.text }
            ?? type.as(MemberTypeSyntax.self).map { "\($0.baseType.trimmedDescription).\($0.name.text)" } ?? ""
        return "\(base)<\(arguments.joined(separator: ", "))>"
    }
}

extension Crawler {
    /// The names a file declares that change how other files are mocked.
    struct DeclaredNames {
        /// The global actors (`@globalActor actor X`, or a class, struct or enum), so attributes naming them can be
        /// told apart from macros and property wrappers.
        var globalActors: Set<String> = []
        /// The `~Copyable` structs and enums, by qualified name, whose arguments mocks record as placeholders.
        var noncopyableTypes: Set<String> = []
        /// The `~Copyable` generic types an extension makes `Copyable` for copyable arguments, by qualified name.
        var conditionallyCopyableTypes: Set<String> = []

        /// The types that are `~Copyable` wherever they're used: those without a conditional `Copyable` extension.
        var unconditionallyNoncopyableTypes: Set<String> {
            noncopyableTypes.subtracting(conditionallyCopyableTypes)
        }
        /// The typealiases of function types, by qualified name, to the function type they stand for; a generic one's
        /// starts with its generic parameters, as in `<T> (T) -> Void`. See `Crawler.functionType(of:)`.
        var closureTypealiases: [String: String] = [:]
        /// The types declared without `public` or `open`, which a public declaration can't name.
        var nonPublicTypes: Set<String> = []
        /// The types declared `public` or `open`, for resolving type names; a name that's also in `nonPublicTypes`
        /// still makes a mock internal, which compiles either way.
        var publicTypes: Set<String> = []
        /// The generic structs, classes and enums, which a call can't name as a type without its generic arguments.
        var genericTypes: Set<String> = []
        /// The same, by qualified name, so a scope can tell `Outer.Box<T>` from an unrelated `Box`.
        var qualifiedGenericTypes: Set<String> = []
        /// The types an extension declares `@unchecked Sendable`, by qualified name, which a subclass has to restate.
        var uncheckedSendableTypes: Set<String> = []
        /// The protocols and classes, by name: a protocol's parent outside them isn't implemented by its mock.
        var protocolsAndClasses: Set<String> = []
        /// The typealiases of protocol compositions, `typealias AB = A & B`, by name, to the composed types.
        var compositionTypealiases: [String: [String]] = [:]
        /// The actors, so an extension of one is known to be an actor's.
        var actors: Set<String> = []
        /// The typealiases of other named types, `typealias Service = Feature.Service`, by qualified name.
        var typealiases: [String: String] = [:]
        /// The names declared `private` or `fileprivate`: members, top-level declarations and types.
        var privateNames: Set<String> = []
        /// The structs, classes, enums, actors and protocols, by name.
        var nominalTypes: Set<String> = []

        /// The entry in ``privateNames`` for a type with a `private` or `fileprivate` initializer: a call of the
        /// type, `Name(…)` or `Name.init(…)`, may need it.
        static func privateInitializerName(of type: String) -> String {
            "\(type)("
        }

        mutating func formUnion(_ other: DeclaredNames) {
            actors.formUnion(other.actors)
            typealiases.merge(other.typealiases) { first, _ in first }
            privateNames.formUnion(other.privateNames)
            nominalTypes.formUnion(other.nominalTypes)
            globalActors.formUnion(other.globalActors)
            noncopyableTypes.formUnion(other.noncopyableTypes)
            conditionallyCopyableTypes.formUnion(other.conditionallyCopyableTypes)
            nonPublicTypes.formUnion(other.nonPublicTypes)
            publicTypes.formUnion(other.publicTypes)
            genericTypes.formUnion(other.genericTypes)
            qualifiedGenericTypes.formUnion(other.qualifiedGenericTypes)
            uncheckedSendableTypes.formUnion(other.uncheckedSendableTypes)
            protocolsAndClasses.formUnion(other.protocolsAndClasses)
            compositionTypealiases.merge(other.compositionTypealiases) { first, _ in first }
            closureTypealiases.merge(other.closureTypealiases) { first, _ in first }
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

        private func collectAccess(_ modifiers: DeclModifierListSyntax, name: TokenSyntax, at node: some SyntaxProtocol) {
            collectPrivate(modifiers, names: [name], at: node)
            let isPublic = modifiers.contains { $0.name.tokenKind == .keyword(.public) || $0.name.tokenKind == .keyword(.open) }
            if isPublic {
                names.publicTypes.insert(name.text)
            } else {
                names.nonPublicTypes.insert(name.text)
            }
        }

        override func visit(_ node: ProtocolDeclSyntax) -> SyntaxVisitorContinueKind {
            names.nominalTypes.insert(node.name.text)
            names.nominalTypes.insert(Self.qualifiedName(of: node.name.text, at: Syntax(node)))
            collectAccess(node.modifiers, name: node.name, at: node)
            names.protocolsAndClasses.insert(node.name.text)
            // Its typealiases count, as `typealias Callback = …` does for the protocols that refine it.
            return .visitChildren
        }

        override func visit(_ node: ExtensionDeclSyntax) -> SyntaxVisitorContinueKind {
            // `extension Box: Copyable where T: Copyable` makes a `~Copyable` generic type copyable for copyable
            // arguments, which is how it's almost always used.
            if node.inheritanceClause?.inheritedTypes.contains(where: { $0.type.trimmedDescription == "Copyable" }) == true {
                let extended = node.extendedType.as(IdentifierTypeSyntax.self)?.name.text ?? node.extendedType.trimmedDescription
                names.conditionallyCopyableTypes.insert(Self.qualifiedName(of: extended, at: Syntax(node)))
            }
            if node.inheritanceClause?.inheritedTypes.contains(where: { Crawler.isUncheckedSendable($0.type) }) == true {
                names.uncheckedSendableTypes.insert(Self.qualifiedName(of: node.extendedType.trimmedDescription, at: Syntax(node)))
            }
            return .visitChildren
        }

        private func collect(_ attributes: AttributeListSyntax, inheritance: InheritanceClauseSyntax?, name: TokenSyntax) {
            let isGlobalActor = attributes.contains { element in
                element.as(AttributeSyntax.self)?.attributeName.trimmedDescription == "globalActor"
            }
            if isGlobalActor {
                names.globalActors.insert(name.text)
            }
            if inheritance?.inheritedTypes.contains(where: { Crawler.suppressesCopyable($0.type) }) == true {
                names.noncopyableTypes.insert(Self.qualifiedName(of: name.text, at: name.parent ?? Syntax(name)))
            }
        }

        /// `Outer.Inner.Name` for a declaration nested in `Outer.Inner`, `Name` at the top level.
        static func qualifiedName(of node: TypeAliasDeclSyntax) -> String {
            qualifiedName(of: node.name.text, at: Syntax(node))
        }

        /// `Outer.Inner.name` for a declaration `name` at `node`, nested in `Outer.Inner`.
        static func qualifiedName(of name: String, at node: Syntax) -> String {
            var components = [name]
            var ancestor = node.parent
            while let current = ancestor {
                if let named = current.asProtocol((any NamedDeclSyntax).self), current.is(MemberBlockSyntax.self) == false,
                   current.asProtocol((any DeclGroupSyntax).self) != nil {
                    components.insert(named.name.text, at: 0)
                } else if let extensionDeclaration = current.as(ExtensionDeclSyntax.self) {
                    components.insert(extensionDeclaration.extendedType.trimmedDescription, at: 0)
                }
                ancestor = current.parent
            }
            return components.joined(separator: ".")
        }

        private static func isPrivate(_ modifiers: DeclModifierListSyntax) -> Bool {
            modifiers.contains { $0.name.tokenKind == .keyword(.private) || $0.name.tokenKind == .keyword(.fileprivate) }
        }

        /// Whether a member is private: declared so, or in a `private` or `fileprivate` extension, whose members
        /// state no access of their own.
        private static func isPrivateMember(_ modifiers: DeclModifierListSyntax, at node: some SyntaxProtocol) -> Bool {
            if isPrivate(modifiers) {
                return true
            }
            return enclosingGroup(of: node)?.as(ExtensionDeclSyntax.self).map { isPrivate($0.modifiers) } ?? false
        }

        /// The type or extension a declaration is a member of, through any `#if` around it, or nil for a
        /// top-level or local declaration.
        private static func enclosingGroup(of node: some SyntaxProtocol) -> Syntax? {
            var parent = node.parent
            while let current = parent {
                if current.isProtocol((any DeclGroupSyntax).self) {
                    return current
                }
                if current.is(CodeBlockSyntax.self) || current.is(SourceFileSyntax.self) || current.is(ClosureExprSyntax.self) {
                    return nil
                }
                parent = current.parent
            }
            return nil
        }

        private func collectPrivate(_ modifiers: DeclModifierListSyntax, names: [TokenSyntax], at node: some SyntaxProtocol) {
            if Self.isPrivateMember(modifiers, at: node) {
                self.names.privateNames.formUnion(names.map(\.text))
            }
        }

        override func visit(_ node: VariableDeclSyntax) -> SyntaxVisitorContinueKind {
            collectPrivate(node.modifiers, names: node.bindings.compactMap { $0.pattern.as(IdentifierPatternSyntax.self)?.identifier }, at: node)
            return .skipChildren
        }

        override func visit(_ node: FunctionDeclSyntax) -> SyntaxVisitorContinueKind {
            collectPrivate(node.modifiers, names: [node.name], at: node)
            return .skipChildren
        }

        /// A private initializer has no name a default could name, so a default that calls its type, as in
        /// `Token(secret: 0)`, may need it: the type goes in as ``DeclaredNames/privateInitializerName(of:)``. A
        /// default that only names the type, such as `Config.shared`, keeps it. Leaving such a default out is always safe.
        override func visit(_ node: InitializerDeclSyntax) -> SyntaxVisitorContinueKind {
            if Self.isPrivateMember(node.modifiers, at: node), let group = Self.enclosingGroup(of: node) {
                if let named = group.asProtocol((any NamedDeclSyntax).self) {
                    names.privateNames.insert(DeclaredNames.privateInitializerName(of: named.name.text))
                } else if let extensionDeclaration = group.as(ExtensionDeclSyntax.self),
                          let name = extensionDeclaration.extendedType.trimmedDescription.split(separator: ".").last {
                    names.privateNames.insert(DeclaredNames.privateInitializerName(of: String(name)))
                }
            }
            return .skipChildren
        }

        override func visit(_ node: ActorDeclSyntax) -> SyntaxVisitorContinueKind {
            names.nominalTypes.insert(node.name.text)
            names.nominalTypes.insert(Self.qualifiedName(of: node.name.text, at: Syntax(node)))
            names.actors.insert(Self.qualifiedName(of: node.name.text, at: Syntax(node)))
            collect(node.attributes, inheritance: node.inheritanceClause, name: node.name)
            collectAccess(node.modifiers, name: node.name, at: node)
            return .visitChildren
        }

        override func visit(_ node: TypeAliasDeclSyntax) -> SyntaxVisitorContinueKind {
            // A protocol's typealias has the protocol's access, which it can't state itself.
            if let enclosingProtocol = node.parent?.parent?.parent?.parent?.as(ProtocolDeclSyntax.self) {
                collectAccess(enclosingProtocol.modifiers, name: node.name, at: node)
            } else {
                collectAccess(node.modifiers, name: node.name, at: node)
            }
            var type = node.initializer.value
            if let attributed = type.as(AttributedTypeSyntax.self), attributed.specifiers.isEmpty {
                type = attributed.baseType
            }
            // Keyed by qualified name; a use finds it by scope, see `closureTypealias(named:from:)`.
            if let function = Crawler.functionType(of: node) {
                names.closureTypealiases[Self.qualifiedName(of: node)] = function
            }
            if node.genericParameterClause == nil, type.is(IdentifierTypeSyntax.self) || type.is(MemberTypeSyntax.self) {
                names.typealiases[Self.qualifiedName(of: node)] = type.trimmedDescription
            }
            if node.genericParameterClause == nil, let composition = type.as(CompositionTypeSyntax.self) {
                names.compositionTypealiases[node.name.text] = composition.elements.map { $0.type.trimmedDescription }
            }
            return .skipChildren
        }

        override func visit(_ node: ClassDeclSyntax) -> SyntaxVisitorContinueKind {
            names.nominalTypes.insert(node.name.text)
            names.nominalTypes.insert(Self.qualifiedName(of: node.name.text, at: Syntax(node)))
            collect(node.attributes, inheritance: node.inheritanceClause, name: node.name)
            collectAccess(node.modifiers, name: node.name, at: node)
            names.protocolsAndClasses.insert(node.name.text)
            if node.genericParameterClause != nil {
                names.genericTypes.insert(node.name.text)
                names.qualifiedGenericTypes.insert(Self.qualifiedName(of: node.name.text, at: Syntax(node)))
            }
            return .visitChildren
        }

        override func visit(_ node: StructDeclSyntax) -> SyntaxVisitorContinueKind {
            names.nominalTypes.insert(node.name.text)
            names.nominalTypes.insert(Self.qualifiedName(of: node.name.text, at: Syntax(node)))
            collect(node.attributes, inheritance: node.inheritanceClause, name: node.name)
            collectAccess(node.modifiers, name: node.name, at: node)
            if node.genericParameterClause != nil {
                names.genericTypes.insert(node.name.text)
                names.qualifiedGenericTypes.insert(Self.qualifiedName(of: node.name.text, at: Syntax(node)))
            }
            return .visitChildren
        }

        override func visit(_ node: EnumDeclSyntax) -> SyntaxVisitorContinueKind {
            names.nominalTypes.insert(node.name.text)
            names.nominalTypes.insert(Self.qualifiedName(of: node.name.text, at: Syntax(node)))
            collect(node.attributes, inheritance: node.inheritanceClause, name: node.name)
            collectAccess(node.modifiers, name: node.name, at: node)
            if node.genericParameterClause != nil {
                names.genericTypes.insert(node.name.text)
                names.qualifiedGenericTypes.insert(Self.qualifiedName(of: node.name.text, at: Syntax(node)))
            }
            return .visitChildren
        }
    }
}

extension GenericParameterSyntax {
    /// Whether this is a parameter pack (`each T`). The `specifier` also holds the `let` of a value generic.
    var isPack: Bool {
        specifier?.tokenKind == .keyword(.each)
    }

    var kind: GenericParameter.Kind {
        switch specifier?.tokenKind {
        case .keyword(.each): .pack
        case .keyword(.let): .value
        default: .type
        }
    }
}
