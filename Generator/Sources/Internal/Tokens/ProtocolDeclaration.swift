import RegexBuilder
import SwiftParser
import SwiftSyntax

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
    /// Whether the declared superclass is `@unchecked Sendable`, which a subclass has to restate.
    var isSuperclassUncheckedSendable = false
    /// Requirements of the protocol's or its associated types' `where` clauses that neither constrain an associated
    /// type nor fix one, such as `Items.Element == Int`: the mock and stub repeat them in their own `where` clause.
    var whereRequirements: [String] = []
    /// Whether ``isolation`` is the module's default isolation rather than one the protocol states. A parent's
    /// stated isolation replaces it, as it does in Swift.
    var isIsolationDefault = false
    /// Whether a parent protocol refines `Actor`, which makes this one an actor protocol too.
    var inheritsActor = false
    /// Whether a parent protocol states `Sendable`, which makes this one `Sendable` too.
    var inheritsSendable = false
    /// Attributes the generator couldn't classify, which the mock names in a comment; see `Crawler.unknownAttributes`.
    var unknownAttributes: [String] = []
    /// Parent protocols declared outside the mocked sources, whose requirements the mock doesn't implement.
    var parentsOutsideSources: [String] = []
    /// Typealiases, as `Model = Feature.Model`, for the types the scopes around the one this is nested in declare:
    /// the mock and stub sit in an extension of that type, which doesn't see them. See `Generator.outerScopeTypealiases`.
    var outerScopeTypealiases: [OuterScopeTypealias] = []
    /// The protocol's typealiases, its parents' included, of types that name a non-primary associated type, as
    /// `typealias Items = [Item]`, by the names the mock has for them. The members' `parent` has no members, so
    /// it carries these for ``erasedTypeNames``.
    var associatedTypeTypealiases: [String] = []

    /// The global actor the protocol is isolated to, if any.
    var globalActor: String? {
        if case .globalActor(let name)? = isolation { name } else { nil }
    }

    /// Whether the protocol refines `Actor`, so its mock is an `actor`.
    var isActor: Bool {
        inheritsActor || inheritedTypes.contains { $0 == "Actor" || $0 == "_Concurrency.Actor" }
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
            isSuperclassDeclared: isSuperclassDeclared,
            isSuperclassUncheckedSendable: isSuperclassUncheckedSendable,
            whereRequirements: whereRequirements,
            isIsolationDefault: isIsolationDefault,
            inheritsActor: inheritsActor,
            inheritsSendable: inheritsSendable,
            unknownAttributes: unknownAttributes,
            parentsOutsideSources: parentsOutsideSources,
            associatedTypeTypealiases: associatedTypeTypealiases
        )
    }

    /// The protocol bound to `superclass`, with `declaration` when the class is declared in the sources. Its
    /// isolation becomes the protocol's, unless the protocol states its own.
    func replacing(superclass: String, declaration: ClassDeclaration?) -> ProtocolDeclaration {
        var protocolDeclaration = self
        protocolDeclaration.superclass = superclass
        protocolDeclaration.isSuperclassDeclared = declaration != nil
        protocolDeclaration.isSuperclassUncheckedSendable = declaration?.isUncheckedSendable ?? false
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
        var whereRequirements: [String] = []
        for (parent, arguments) in parents {
            fixedTypes += zip(parent.primaryAssociatedTypes, arguments).map { ($0.name, $1) }
        }
        let associatedTypeNames = Set((associatedTypes + primaryAssociatedTypes + parents.flatMap(\.declaration.genericParameters)).map(\.name))
        for requirement in genericRequirements {
            // Inside the mock, `Self.Items` is its generic parameter `Items`.
            let requirement = requirement.replacing(#/\bSelf\./#, with: "")
            let separator = requirement.firstRange(of: "==") ?? requirement.firstRange(of: ":")
            guard let separator else { continue }
            let name = requirement[..<separator.lowerBound].trimmedSpaces
            let type = requirement[separator.upperBound...].trimmedSpaces
            guard associatedTypeNames.contains(name) else {
                let root = String(name.split(separator: ".").first ?? "")
                if name.contains("."), associatedTypeNames.contains(root) {
                    // A nested type, as in `Items.Element == Int`: the mock states it in its `where` clause.
                    whereRequirements.append(requirement)
                } else if name != "Self", !name.contains("."), requirement[separator] == "==" {
                    // An associated type of a parent outside the sources, as `ID` of `Identifiable`: the mock fixes
                    // it with a typealias, since it has no generic parameter of that name to constrain.
                    fixedTypes.append((name, type))
                }
                // Anything else names what the mock can't constrain, such as a conformance of an outside parent's
                // associated type; Swift checks it on the mock's own declarations.
                continue
            }
            if requirement[separator] == "==" {
                fixedTypes.append((name, type))
            } else {
                constraints[name, default: []].append(type)
            }
        }
        let fixedNames = Set(fixedTypes.map(\.name))
        let inheritedAssociatedTypes = parents.flatMap(\.declaration.genericParameters)

        // A fixed associated type is a typealias in the mock, so the mock's own declaration, where the remaining
        // ones are its generic parameters, names its type instead: `Keys: Collection<Key>` is `Collection<Int>`.
        func fixingType(_ type: String) -> String {
            replacingTypeReferences(fixedTypes, in: type)
        }
        func fixingRequirement(_ requirement: String) -> String {
            let isSameType = requirement.contains("==")
            let parts = requirement.split(separator: isSameType ? "==" : ":", maxSplits: 1)
            guard parts.count == 2 else { return requirement }
            let left = fixingType(String(parts[0].trimmedSpaces))
            let right = fixingType(String(parts[1].trimmedSpaces))
            return isSameType ? "\(left) == \(right)" : "\(left): \(right)"
        }

        var protocolDeclaration = self.inheritingIsolation(from: parents.map(\.declaration))
        protocolDeclaration.whereRequirements = (whereRequirements + parents.flatMap(\.declaration.whereRequirements)).map(fixingRequirement).uniquing()
        protocolDeclaration.associatedTypes = (associatedTypes + inheritedAssociatedTypes)
            .merged()
            .filter { !fixedNames.contains($0.name) }
            .map { GenericParameter(name: $0.name, inheritedTypes: ($0.inheritedTypes + constraints[$0.name, default: []]).map(fixingType).uniquing(), kind: $0.kind, condition: $0.condition) }
        protocolDeclaration.primaryAssociatedTypes = primaryAssociatedTypes.filter { !fixedNames.contains($0.name) }
        // A requirement on fixed types only, as `[String].Element: Hashable`, holds already, and a mock left with no
        // generic parameters can't state it.
        let remaining = protocolDeclaration.associatedTypes.map(\.name)
        protocolDeclaration.whereRequirements = protocolDeclaration.whereRequirements.filter { requirement in
            remaining.contains { name in requirement.contains(Regex { Anchor.wordBoundary; name; Anchor.wordBoundary }.wordBoundaryKind(.simple)) }
        }
        // A parent's typealiases arrive with its members; keep one of each.
        var aliases: Set<String> = []
        let ownMembers = Self.unqualifyingSelf(in: members, associatedTypes: associatedTypeNames)
        protocolDeclaration.members = Self.expandingFunctionTypes(fixedTypes, in: ownMembers + fixedTypes.map { Typealias(alias: $0.name, original: $0.type) as any Token })
            .filter { member in
                guard let typealiasToken = member as? Typealias else { return true }
                return aliases.insert(typealiasToken.alias).inserted
            }
        protocolDeclaration.associatedTypeTypealiases = Self.typealiases(naming: protocolDeclaration.nonPrimaryAssociatedTypes.map(\.name), in: protocolDeclaration.members)
        return protocolDeclaration
    }

    /// The members with `Self.Item` written as `Item`, `Self.Item.Element` included, whatever `Item` is: an associated
    /// type, a typealias of the protocol, of a parent or of an extension. Inside the mock, a class, `Self.Item` names
    /// no member type, and the unqualified name finds what the protocol's `Self` has: the mock's generic parameter
    /// for an associated type, its copy of a typealias, or the typealias through its conformance. `Self.Type` and
    /// `Self.Protocol` are `Self`'s metatypes. A name a member's own generic parameter shadows, `Self.Key` in
    /// `func get<Key>(_ key: Key) -> Self.Key`, is written `__CuckooSelf_Key`, a typealias of `Key` added to the
    /// members for the mock to declare where nothing shadows it. A generic typealias gets a generic one,
    /// `__CuckooSelf_Pair<T> = Pair<T>`. A shadowed associated type stays as written: Swift doesn't let a member of
    /// the generic mock shadow its generic parameter at all.
    private static func unqualifyingSelf(in members: [any Token], associatedTypes: Set<String>) -> [any Token] {
        /// The shadowed names the members use, with the number of generic arguments each is given.
        final class ShadowedNames {
            var arguments: [String: Int] = [:]
        }
        final class Unqualifier: SyntaxRewriter {
            let shadowed: Set<String>
            /// Where to note a shadowed name; without it, a shadowed name stays as written.
            let shadowedNames: ShadowedNames?
            init(shadowing shadowed: Set<String> = [], noting shadowedNames: ShadowedNames? = nil) {
                self.shadowed = shadowed
                self.shadowedNames = shadowedNames
            }
            override func visit(_ node: MemberTypeSyntax) -> TypeSyntax {
                let name = node.name.text
                guard node.baseType.as(IdentifierTypeSyntax.self)?.name.text == "Self", name != "Type", name != "Protocol" else {
                    return super.visit(node)
                }
                // The arguments can name `Self`'s types too, as in `Self.Box<Self.Item>`.
                let arguments = node.genericArgumentClause.map { rewrite($0).cast(GenericArgumentClauseSyntax.self) }
                var identifier = node.name
                if shadowed.contains(name) {
                    guard let shadowedNames else { return super.visit(node) }
                    shadowedNames.arguments[name] = arguments?.arguments.count ?? 0
                    identifier = .identifier(GeneratedNames.selfTypealiasPrefix + name)
                }
                let type = IdentifierTypeSyntax(name: identifier, genericArgumentClause: arguments)
                return TypeSyntax(type.with(\.leadingTrivia, node.leadingTrivia).with(\.trailingTrivia, node.trailingTrivia))
            }
        }
        let shadowedNames = ShadowedNames()
        func unqualified(_ type: String, shadowing shadowed: Set<String> = []) -> String? {
            guard type.contains("Self.") else { return nil }
            var parser = Parser(type)
            let syntax = TypeSyntax.parse(from: &parser)
            let unqualifier = Unqualifier(shadowing: shadowed, noting: shadowed.isDisjoint(with: associatedTypes) ? shadowedNames : nil)
            let rewritten = unqualifier.rewrite(syntax).trimmedDescription
            return rewritten == syntax.trimmedDescription ? nil : rewritten
        }
        // Constraints are text, as in `T.Element == Self.Item.Element`: each side is a type.
        func text(_ text: String) -> String {
            guard text.contains("Self.") else { return text }
            guard let declaration = Parser.parse(source: "typealias __CuckooType<T> = T where \(text)").statements.first?.item.as(TypeAliasDeclSyntax.self),
                  let clause = declaration.genericWhereClause,
                  !declaration.hasError else { return text }
            return Unqualifier().rewrite(clause.requirements).trimmedDescription
        }
        // The mock declares the protocol's typealiases again, where `Self` can't be written either.
        let members = members.map { member -> any Token in
            guard let alias = member as? Typealias, let original = unqualified(alias.original) else { return member }
            return Typealias(parent: alias.parent, alias: alias.alias, original: original)
        }
        let rewritten = rewritingTypes(in: members, text: text) { type, shadowed in
            guard let rewritten = unqualified(type.description, shadowing: shadowed) else { return type }
            var parser = Parser(rewritten)
            return ComplexType(syntax: TypeSyntax.parse(from: &parser))
        }
        // A typealias the protocol declares gives its generic parameters; one from an extension is only known by
        // the arguments it's given.
        let declared = Dictionary(
            members.compactMap { $0 as? Typealias }.map { alias -> (String, [String]) in
                // `Pair<T, U: Hashable>`: the names only.
                let clause = alias.alias.drop { $0 != "<" }.dropFirst().dropLast()
                let parameters = clause.split(separator: ",").map { String($0.prefix { $0 != ":" }.trimmedSpaces) }
                return (String(alias.alias.prefix { $0 != "<" }), parameters)
            },
            uniquingKeysWith: { first, _ in first }
        )
        let unshadowed = shadowedNames.arguments.sorted { $0.key < $1.key }.map { name, count -> any Token in
            let parameters = declared[name] ?? (1...max(count, 1)).prefix(count).map { "__T\($0)" }
            let clause = parameters.isEmpty ? "" : "<\(parameters.joined(separator: ", "))>"
            return Typealias(alias: GeneratedNames.selfTypealiasPrefix + name + clause, original: name + clause)
        }
        return rewritten + unshadowed
    }

    /// The members with each associated type fixed to a function type, as `Transforming<(Int) -> String>` fixes
    /// `Input`, written out in their parameters: such a parameter is a non-escaping closure, which the mock has to
    /// make escaping to record, and it only knows a closure written as one. Inside a closure's own parameters the
    /// function type is `@escaping`, as the associated type's witness is. A member's generic parameter of the same
    /// name shadows it. The crawler has already written a function typealias in the parent's argument out.
    private static func expandingFunctionTypes(_ fixedTypes: [(name: String, type: String)], in members: [any Token]) -> [any Token] {
        let functionTypes = fixedTypes.filter { _, type in
            var parser = Parser(type)
            return ComplexType(syntax: TypeSyntax.parse(from: &parser)).withoutAttributes().isClosure
        }
        guard !functionTypes.isEmpty else { return members }
        final class Expander: SyntaxRewriter {
            let replacements: [String: String]
            init(_ replacements: [String: String]) { self.replacements = replacements }
            override func visit(_ node: IdentifierTypeSyntax) -> TypeSyntax {
                guard node.genericArgumentClause == nil, let functionType = replacements[node.name.text] else {
                    return super.visit(node)
                }
                // A closure's parameter: the witness of the associated type is an escaping function.
                let isClosureParameter = node.parent?.as(TupleTypeElementSyntax.self)?.parent?.parent?.is(FunctionTypeSyntax.self) == true
                // The base of `sending Input` or `inout Input` takes the function type as written; a parenthesized one
                // elsewhere keeps `[Input]` or `Input?` meaning what they did.
                let isAttributedBase = node.parent?.is(AttributedTypeSyntax.self) == true
                let source = isClosureParameter ? "@escaping \(functionType)" : isAttributedBase ? functionType : "(\(functionType))"
                var parser = Parser(source)
                return TypeSyntax.parse(from: &parser).with(\.leadingTrivia, node.leadingTrivia).with(\.trailingTrivia, node.trailingTrivia)
            }
        }
        let replacements = Dictionary(functionTypes.map { ($0.name, $0.type) }) { first, _ in first }
        return rewritingTypes(in: members, results: false, text: { $0 }) { type, shadowed in
            let visible = replacements.filter { !shadowed.contains($0.key) }
            guard !visible.isEmpty else { return type }
            var parser = Parser(type.description)
            let syntax = TypeSyntax.parse(from: &parser)
            // A parameter that is the associated type itself takes the function type as written.
            if let identifier = syntax.as(IdentifierTypeSyntax.self), identifier.genericArgumentClause == nil,
               let functionType = visible[identifier.name.text] {
                var functionParser = Parser(functionType)
                return ComplexType(syntax: TypeSyntax.parse(from: &functionParser))
            }
            let rewritten = Expander(visible).rewrite(syntax).cast(TypeSyntax.self)
            return rewritten.trimmedDescription == syntax.trimmedDescription ? type : ComplexType(syntax: rewritten)
        }
    }

    /// The members with `transform` applied to every parameter type of their methods, initializers and subscripts,
    /// given the names their own generic parameters shadow, and `text` to their constraints. With `results`, also to
    /// result and property types, which a function type expansion leaves alone: those compile through the typealias.
    private static func rewritingTypes(
        in members: [any Token],
        results: Bool = true,
        text: @escaping (String) -> String,
        types transform: @escaping (ComplexType, Set<String>) -> ComplexType
    ) -> [any Token] {
        func parameters(_ parameters: [MethodParameter], shadowing shadowed: Set<String>) -> [MethodParameter] {
            parameters.map { parameter in
                var parameter = parameter
                parameter.type = transform(parameter.type, shadowed)
                parameter.variadicElement = parameter.variadicElement.map { transform($0, shadowed) }
                return parameter
            }
        }
        func signature(_ signature: Method.Signature, results: Bool) -> Method.Signature {
            let shadowed = Set(signature.genericParameters.map(\.name))
            return Method.Signature(
                genericParameters: signature.genericParameters.map { generic in
                    var rewritten = GenericParameter(name: generic.name, inheritedTypes: generic.inheritedTypes.map(text), kind: generic.kind)
                    rewritten.condition = generic.condition
                    return rewritten
                },
                parameters: parameters(signature.parameters, shadowing: shadowed),
                asyncType: signature.asyncType,
                throwType: signature.throwType,
                returnType: results ? signature.returnType.map { transform($0, shadowed) } : signature.returnType,
                whereConstraints: signature.whereConstraints.map(text)
            )
        }
        return members.map { member in
            switch member {
            case var method as Method:
                method.signature = signature(method.signature, results: results)
                return method
            case var initializer as Initializer:
                initializer.signature = signature(initializer.signature, results: results)
                return initializer
            case var variable as Variable where results:
                variable.type = transform(variable.type, [])
                return variable
            case var subscriptDeclaration as Subscript:
                let shadowed = Set(subscriptDeclaration.genericParameters.map(\.name))
                subscriptDeclaration.parameters = parameters(subscriptDeclaration.parameters, shadowing: shadowed)
                if results {
                    subscriptDeclaration.returnType = transform(subscriptDeclaration.returnType, shadowed)
                }
                subscriptDeclaration.whereConstraints = subscriptDeclaration.whereConstraints.map(text)
                return subscriptDeclaration
            default:
                return member
            }
        }
    }

    /// The protocol with what its parents make it: an actor protocol if one refines `Actor`, `Sendable` if one is,
    /// and isolated to a parent's global actor unless it states an isolation of its own. Swift infers a protocol's
    /// isolation from the protocols it refines, so a `@MainActor` parent's members stay main-actor isolated.
    private func inheritingIsolation(from parents: [ProtocolDeclaration]) -> ProtocolDeclaration {
        var protocolDeclaration = self
        protocolDeclaration.inheritsActor = inheritsActor || parents.contains(where: \.isActor)
        protocolDeclaration.inheritsSendable = inheritsSendable || parents.contains(where: \.isDeclaredSendable)
        if protocolDeclaration.isActor, isIsolationDefault {
            // An actor protocol is isolated to its conforming actor, never to the default.
            protocolDeclaration.isolation = nil
            protocolDeclaration.isIsolationDefault = false
        } else if isolation == nil || isIsolationDefault,
                  let parentIsolation = parents.first(where: { $0.globalActor != nil && !$0.isIsolationDefault })?.isolation {
            protocolDeclaration.isolation = parentIsolation
            protocolDeclaration.isIsolationDefault = false
        }
        return protocolDeclaration
    }

    var genericParameters: [GenericParameter] {
        (associatedTypes + primaryAssociatedTypes).merged()
    }
    
    /// The names whose types an existential of the protocol erases: its non-primary associated types, and its
    /// typealiases of types that name one, as `typealias Items = [Item]`, with the mock's own names for them. A
    /// generic member's default implementation is called on the opened existential, where these are other types.
    var erasedTypeNames: [String] {
        let names = nonPrimaryAssociatedTypes.map(\.name)
        return names.isEmpty ? [] : names + associatedTypeTypealiases
    }

    /// The names of `members`' typealiases of types that name one of `associatedTypes`, directly or through
    /// another such typealias.
    private static func typealiases(naming associatedTypes: [String], in members: [any Token]) -> [String] {
        let aliases = members.compactMap { $0 as? Typealias }
        var names = associatedTypes
        var found = true
        while found {
            found = false
            for alias in aliases {
                let name = String(alias.alias.prefix { $0 != "<" })
                let words = Set(alias.original.split { !($0.isLetter || $0.isNumber || $0 == "_") }.map(String.init))
                if !names.contains(name), !words.isDisjoint(with: names) {
                    names.append(name)
                    found = true
                }
            }
        }
        return Array(names.dropFirst(associatedTypes.count))
    }

    /// An erased type as the opened existential `opened` has it: `opened.Item`, and `opened.Items` for the
    /// mock's `__CuckooSelf_Items` too.
    static func openedTypeName(_ name: String, in opened: String) -> String {
        "\(opened).\(name.hasPrefix(GeneratedNames.selfTypealiasPrefix) ? String(name.dropFirst(GeneratedNames.selfTypealiasPrefix.count)) : name)"
    }

    var nonPrimaryAssociatedTypes: [GenericParameter] {
        associatedTypes.filter { !primaryAssociatedTypes.map(\.name).contains($0.name) }
    }
}
