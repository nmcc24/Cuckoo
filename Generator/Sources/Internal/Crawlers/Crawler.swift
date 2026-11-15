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
        url: URL,
        globalActors: Set<String> = [],
        noncopyableTypes: Set<String> = [],
        closureTypealiases: [String: String] = [:],
        nonPublicTypes: Set<String> = [],
        genericTypes: Set<String> = [],
        protocolsAndClasses: Set<String>? = nil,
        compositionTypealiases: [String: [String]] = [:],
        actors: Set<String> = [],
        privateNames: Set<String> = [],
        nominalTypes: Set<String> = [],
        defaultIsolation: Isolation? = nil
    ) throws -> Crawler {
        let file = try String(contentsOf: url, encoding: .utf8)
        return crawl(
            source: file,
            url: url,
            globalActors: globalActors,
            noncopyableTypes: noncopyableTypes,
            closureTypealiases: closureTypealiases,
            nonPublicTypes: nonPublicTypes,
            genericTypes: genericTypes,
            protocolsAndClasses: protocolsAndClasses,
            compositionTypealiases: compositionTypealiases,
            actors: actors,
            privateNames: privateNames,
            nominalTypes: nominalTypes,
            defaultIsolation: defaultIsolation
        )
    }

    static func crawl(
        source: String,
        url: URL,
        globalActors: Set<String> = [],
        noncopyableTypes: Set<String> = [],
        closureTypealiases: [String: String] = [:],
        nonPublicTypes: Set<String> = [],
        genericTypes: Set<String> = [],
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
        /// The module's non-generic typealiases of function types, by name, to the function type.
        let closureTypealiases: [String: String]
        /// The module's types declared without `public` or `open`.
        let nonPublicTypes: Set<String>
        /// The module's generic structs, classes and enums.
        let genericTypes: Set<String>
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

        init(
            url: URL,
            locationConverter: SourceLocationConverter,
            globalActors: Set<String>,
            noncopyableTypes: Set<String>,
            closureTypealiases: [String: String] = [:],
            nonPublicTypes: Set<String> = [],
            genericTypes: Set<String> = [],
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
        let inheritedTypes = expandingCompositions(inheritedTypes(from: node.inheritanceClause?.inheritedTypes))
            + (node.genericWhereClause?.requirements ?? []).flatMap { requirement -> [String] in
                guard let conformance = requirement.requirement.as(ConformanceRequirementSyntax.self),
                      conformance.leftType.trimmedDescription == "Self" else { return [] }
                return self.inheritedTypes(from: conformance.rightType)
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
        if container.isClass, let parameter = node.signature.parameterClause.parameters.first(where: { isUnmockableClosure($0.type) }) {
            unmockedMembers.append("'\(node.name.trimmedDescription)\(node.signature.parameterClause.trimmedDescription)' takes '\(parameter.type.trimmedDescription)', a non-escaping closure with a specifier, which a mock can't record yet.")
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
        if let identifier = type.as(IdentifierTypeSyntax.self), identifier.genericArgumentClause == nil,
           let functionType = closureTypealias(named: identifier.name.text, from: Syntax(type)) {
            var parser = Parser(functionType)
            return ComplexType(syntax: TypeSyntax.parse(from: &parser))
        }
        // A qualified one, `Uploader.Completion`, by its full name.
        if let member = type.as(MemberTypeSyntax.self), member.genericArgumentClause == nil,
           let functionType = context.closureTypealiases[member.trimmedDescription] {
            var parser = Parser(functionType)
            return ComplexType(syntax: TypeSyntax.parse(from: &parser))
        }
        return ComplexType(syntax: type)
    }

    /// The function type `name` stands for where `node` uses it, found as Swift finds it: a generic parameter,
    /// an associated type or a typealias of an enclosing declaration comes first, then the module's top-level
    /// typealiases. A typealias Swift finds elsewhere, in another extension of the type, a superclass or a parent
    /// protocol, is taken when it's the module's only one of that name. Nil when `name` isn't a typealias of a
    /// function type there.
    private func closureTypealias(named name: String, from node: Syntax) -> String? {
        switch closureTypealiasInScope(named: name, from: node) {
        case .shadowed:
            return nil
        case .found(let functionType):
            return functionType
        case .notFound:
            if let topLevel = context.closureTypealiases[name] {
                return topLevel
            }
            // Only when nothing else in the module has the name, which a type of its own would then be.
            guard !context.nominalTypes.contains(name) else { return nil }
            let nested = Set(context.closureTypealiases.filter { $0.key.hasSuffix("." + name) }.values)
            return nested.count == 1 ? nested.first : nil
        }
    }

    private enum ScopedTypealias {
        case shadowed
        case found(String?)
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
                        return .found(Self.functionType(of: alias))
                    }
                }
            }
            ancestor = current.parent
        }
        return .notFound
    }

    /// The function type a non-generic typealias stands for, or nil when it's another type.
    static func functionType(of alias: TypeAliasDeclSyntax) -> String? {
        var type = alias.initializer.value
        if let attributed = type.as(AttributedTypeSyntax.self), attributed.specifiers.isEmpty {
            type = attributed.baseType
        }
        guard alias.genericParameterClause == nil, type.is(FunctionTypeSyntax.self) else { return nil }
        return alias.initializer.value.trimmedDescription
    }

    /// A non-escaping closure written with `sending`, `borrowing` or `inout`, which the mock's recording can't
    /// make escaping yet (roadmap).
    private func isUnmockableClosure(_ type: TypeSyntax) -> Bool {
        guard let attributed = type.as(AttributedTypeSyntax.self),
              attributed.specifiers.contains(where: { ["sending", "borrowing", "inout"].contains($0.trimmedDescription.split(separator: " ").first.map(String.init) ?? "") }),
              !attributed.attributes.contains(where: { $0.trimmedDescription == "@escaping" }) else { return false }
        if attributed.baseType.is(FunctionTypeSyntax.self) {
            return true
        }
        // A closure written through a typealias, `sending Handler`. Through a typealias an `inout` closure is mocked
        // already, as a variable the caller owns.
        guard !attributed.specifiers.contains(where: { $0.trimmedDescription == "inout" }),
              let identifier = attributed.baseType.as(IdentifierTypeSyntax.self), identifier.genericArgumentClause == nil,
              let functionType = closureTypealias(named: identifier.name.text, from: Syntax(type)) else { return false }
        return !functionType.contains("@escaping")
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
            let accessorsContainGet = accessors.contains { $0.accessorSpecifier.tokenKind == .keyword(.get) }
            let accessorsContainSet = accessors.contains { $0.accessorSpecifier.tokenKind == .keyword(.set) }
            isReadOnly = accessorsContainGet && !accessorsContainSet

            let getAccessor = accessors.first { $0.accessorSpecifier.tokenKind == .keyword(.get) }
            effects = Variable.Effects(
                isThrowing: getAccessor?.effectSpecifiers?.throwsClause != nil,
                isAsync: getAccessor?.effectSpecifiers?.asyncSpecifier?.isPresent == true,
                typedError: getAccessor?.effectSpecifiers?.throwsClause?.type?.trimmedDescription
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
                    defaultValue: parameter.defaultValue.flatMap(mockableDefaultValue)
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
                defaultValue: parameter.defaultValue.flatMap(mockableDefaultValue)
            )
        }
    }

    /// A default argument the mock can repeat: not one that names a `private` or `fileprivate` declaration, which
    /// the mock, in another file, can't see. Without its default, a call through the mock's own type passes the
    /// argument, as it did before Cuckoo kept defaults. A name the module declares private anywhere counts, whatever
    /// else shares it, since leaving a default out is always safe; argument labels don't.
    private func mockableDefaultValue(_ clause: InitializerClauseSyntax) -> String? {
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
        }
        let references = References(viewMode: .sourceAccurate)
        references.walk(clause.value)
        return references.names.contains(where: context.privateNames.contains) ? nil : clause.value.trimmedDescription
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
            return conditional.clauses.flatMap { clause -> [GenericParameter] in
                let own = clause.condition.map { "(\($0.trimmedDescription))" }
                let clauseCondition = ([condition].compactMap { $0 } + previous.map { "!\($0)" } + [own].compactMap { $0 })
                    .joined(separator: " && ")
                if let own {
                    previous.append(own)
                }
                guard case .decls(let members)? = clause.elements else { return [] }
                return associatedTypes(from: members, condition: clauseCondition)
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

extension Crawler {
    /// The names a file declares that change how other files are mocked.
    struct DeclaredNames {
        /// The global actors (`@globalActor actor X`, or a class, struct or enum), so attributes naming them can be
        /// told apart from macros and property wrappers.
        var globalActors: Set<String> = []
        /// The `~Copyable` structs and enums, whose arguments mocks record as placeholders.
        var noncopyableTypes: Set<String> = []
        /// The non-generic typealiases of function types, by name, to the function type they stand for.
        var closureTypealiases: [String: String] = [:]
        /// The types declared without `public` or `open`, which a public declaration can't name.
        var nonPublicTypes: Set<String> = []
        /// The types declared `public` or `open`, for resolving type names; a name that's also in `nonPublicTypes`
        /// still makes a mock internal, which compiles either way.
        var publicTypes: Set<String> = []
        /// The generic structs, classes and enums, which a call can't name as a type without its generic arguments.
        var genericTypes: Set<String> = []
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

        mutating func formUnion(_ other: DeclaredNames) {
            actors.formUnion(other.actors)
            typealiases.merge(other.typealiases) { first, _ in first }
            privateNames.formUnion(other.privateNames)
            nominalTypes.formUnion(other.nominalTypes)
            globalActors.formUnion(other.globalActors)
            noncopyableTypes.formUnion(other.noncopyableTypes)
            nonPublicTypes.formUnion(other.nonPublicTypes)
            publicTypes.formUnion(other.publicTypes)
            genericTypes.formUnion(other.genericTypes)
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

        private func collectAccess(_ modifiers: DeclModifierListSyntax, name: TokenSyntax) {
            collectPrivate(modifiers, names: [name])
            let isPublic = modifiers.contains { $0.name.tokenKind == .keyword(.public) || $0.name.tokenKind == .keyword(.open) }
            if isPublic {
                names.publicTypes.insert(name.text)
            } else {
                names.nonPublicTypes.insert(name.text)
            }
        }

        override func visit(_ node: ProtocolDeclSyntax) -> SyntaxVisitorContinueKind {
            names.nominalTypes.insert(node.name.text)
            collectAccess(node.modifiers, name: node.name)
            names.protocolsAndClasses.insert(node.name.text)
            // Its typealiases count, as `typealias Callback = …` does for the protocols that refine it.
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
                names.noncopyableTypes.insert(name.text)
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

        private func collectPrivate(_ modifiers: DeclModifierListSyntax, names: [TokenSyntax]) {
            let isPrivate = modifiers.contains { $0.name.tokenKind == .keyword(.private) || $0.name.tokenKind == .keyword(.fileprivate) }
            if isPrivate {
                self.names.privateNames.formUnion(names.map(\.text))
            }
        }

        override func visit(_ node: VariableDeclSyntax) -> SyntaxVisitorContinueKind {
            collectPrivate(node.modifiers, names: node.bindings.compactMap { $0.pattern.as(IdentifierPatternSyntax.self)?.identifier })
            return .skipChildren
        }

        override func visit(_ node: FunctionDeclSyntax) -> SyntaxVisitorContinueKind {
            collectPrivate(node.modifiers, names: [node.name])
            return .skipChildren
        }

        override func visit(_ node: ActorDeclSyntax) -> SyntaxVisitorContinueKind {
            names.nominalTypes.insert(node.name.text)
            names.actors.insert(Self.qualifiedName(of: node.name.text, at: Syntax(node)))
            collect(node.attributes, inheritance: node.inheritanceClause, name: node.name)
            collectAccess(node.modifiers, name: node.name)
            return .visitChildren
        }

        override func visit(_ node: TypeAliasDeclSyntax) -> SyntaxVisitorContinueKind {
            // A protocol's typealias has the protocol's access, which it can't state itself.
            if let enclosingProtocol = node.parent?.parent?.parent?.parent?.as(ProtocolDeclSyntax.self) {
                collectAccess(enclosingProtocol.modifiers, name: node.name)
            } else {
                collectAccess(node.modifiers, name: node.name)
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
            collect(node.attributes, inheritance: node.inheritanceClause, name: node.name)
            collectAccess(node.modifiers, name: node.name)
            names.protocolsAndClasses.insert(node.name.text)
            if node.genericParameterClause != nil {
                names.genericTypes.insert(node.name.text)
            }
            return .visitChildren
        }

        override func visit(_ node: StructDeclSyntax) -> SyntaxVisitorContinueKind {
            names.nominalTypes.insert(node.name.text)
            collect(node.attributes, inheritance: node.inheritanceClause, name: node.name)
            collectAccess(node.modifiers, name: node.name)
            if node.genericParameterClause != nil {
                names.genericTypes.insert(node.name.text)
            }
            return .visitChildren
        }

        override func visit(_ node: EnumDeclSyntax) -> SyntaxVisitorContinueKind {
            names.nominalTypes.insert(node.name.text)
            collect(node.attributes, inheritance: node.inheritanceClause, name: node.name)
            collectAccess(node.modifiers, name: node.name)
            if node.genericParameterClause != nil {
                names.genericTypes.insert(node.name.text)
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
