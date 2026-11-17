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
            parentsOutsideSources: parentsOutsideSources
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

        var protocolDeclaration = self.inheritingIsolation(from: parents.map(\.declaration))
        protocolDeclaration.whereRequirements = (whereRequirements + parents.flatMap(\.declaration.whereRequirements)).uniquing()
        protocolDeclaration.associatedTypes = (associatedTypes + inheritedAssociatedTypes)
            .merged()
            .filter { !fixedNames.contains($0.name) }
            .map { GenericParameter(name: $0.name, inheritedTypes: ($0.inheritedTypes + constraints[$0.name, default: []]).uniquing(), kind: $0.kind, condition: $0.condition) }
        protocolDeclaration.primaryAssociatedTypes = primaryAssociatedTypes.filter { !fixedNames.contains($0.name) }
        // A parent's typealiases arrive with its members; keep one of each.
        var aliases: Set<String> = []
        let ownMembers = Self.unqualifyingSelf(associatedTypeNames, in: members)
        protocolDeclaration.members = Self.expandingFunctionTypes(fixedTypes, in: ownMembers + fixedTypes.map { Typealias(alias: $0.name, original: $0.type) as any Token })
            .filter { member in
                guard let typealiasToken = member as? Typealias else { return true }
                return aliases.insert(typealiasToken.alias).inserted
            }
        return protocolDeclaration
    }

    /// The members with `Self.Item` written as `Item` for each of the protocol's associated types, `Self.Item.Element`
    /// included: inside the mock, a class generic over them, `Self.Item` names no member type.
    private static func unqualifyingSelf(_ associatedTypes: Set<String>, in members: [any Token]) -> [any Token] {
        guard !associatedTypes.isEmpty else { return members }
        final class Unqualifier: SyntaxRewriter {
            let names: Set<String>
            init(_ names: Set<String>) { self.names = names }
            override func visit(_ node: MemberTypeSyntax) -> TypeSyntax {
                guard node.baseType.as(IdentifierTypeSyntax.self)?.name.text == "Self", names.contains(node.name.text) else {
                    return super.visit(node)
                }
                let identifier = IdentifierTypeSyntax(name: node.name, genericArgumentClause: node.genericArgumentClause)
                return TypeSyntax(identifier.with(\.leadingTrivia, node.leadingTrivia).with(\.trailingTrivia, node.trailingTrivia))
            }
        }
        let unqualifier = Unqualifier(associatedTypes)
        // Constraints are text, as in `T.Element == Self.Item.Element`: each side is a type.
        func text(_ text: String) -> String {
            guard text.contains("Self.") else { return text }
            guard let declaration = Parser.parse(source: "typealias __CuckooType<T> = T where \(text)").statements.first?.item.as(TypeAliasDeclSyntax.self),
                  let clause = declaration.genericWhereClause,
                  !declaration.hasError else { return text }
            return unqualifier.rewrite(clause.requirements).trimmedDescription
        }
        return rewritingTypes(in: members, text: text) { type, _ in
            var parser = Parser(type.description)
            let syntax = TypeSyntax.parse(from: &parser)
            let rewritten = unqualifier.rewrite(syntax).cast(TypeSyntax.self)
            return rewritten.trimmedDescription == syntax.trimmedDescription ? type : ComplexType(syntax: rewritten)
        }
    }

    /// The members with each associated type fixed to a function type, as `Transforming<(Int) -> String>` fixes
    /// `Input`, written out in their parameters: such a parameter is a non-escaping closure, which the mock has to
    /// make escaping to record, and it only knows a closure written as one. Inside a closure's own parameters the
    /// function type is `@escaping`, as the associated type's witness is. A member's generic parameter of the same
    /// name shadows it. A function type the parent's argument names through a typealias isn't recognised.
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
    
    var nonPrimaryAssociatedTypes: [GenericParameter] {
        associatedTypes.filter { !primaryAssociatedTypes.map(\.name).contains($0.name) }
    }
}
