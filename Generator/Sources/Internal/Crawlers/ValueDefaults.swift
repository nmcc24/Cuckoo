import SwiftParser
import SwiftSyntax

/// How a mock builds a value of one of the sources' own structs or enums. A class or an actor has none: creating
/// one may do anything, and a test shouldn't run that without asking.
enum ValueDefault: Sendable, Equatable {
    /// `Type()`, through a struct's initializer of the given access that takes no arguments.
    case initializer(access: Accessibility)
    /// `Type.name`: the enum's first case without associated values.
    case enumCase(String)
}

extension Crawler {
    /// The types a file declares that a mock can build a value of, and every type it declares.
    struct ValueDefaults {
        /// By qualified name, as the sources write it.
        var defaults: [String: ValueDefault] = [:]
        /// The qualified name of every struct, class, actor and enum, with how many times it's declared: a name
        /// declared twice, in two files or two `#if` branches, is no single type.
        var declarations: [String: Int] = [:]
        /// The types an extension declares an initializer for, as the extension names them: `Type()` may then be
        /// ambiguous, or call that initializer.
        var typesWithExtensionInitializers: Set<String> = []

        mutating func formUnion(_ other: ValueDefaults) {
            defaults.merge(other.defaults) { first, _ in first }
            declarations.merge(other.declarations, uniquingKeysWith: +)
            typesWithExtensionInitializers.formUnion(other.typesWithExtensionInitializers)
        }
    }

    /// The value defaults of `source`. Only a declaration that leaves no doubt gets one: the mocks call it from any
    /// isolation, in any build, so a generic type, one under `#if` or an attribute, such as `@MainActor` or
    /// `@available`, and one nested in such a type have none.
    static func valueDefaults(in source: String) -> ValueDefaults {
        let collector = ValueDefaultCollector(viewMode: .sourceAccurate)
        collector.walk(Parser.parse(source: source))
        return collector.result
    }

    private final class ValueDefaultCollector: SyntaxVisitor {
        var result = ValueDefaults()

        override func visit(_ node: StructDeclSyntax) -> SyntaxVisitorContinueKind {
            collect(node, name: node.name) { Self.initializer(of: node.memberBlock, inheritance: node.inheritanceClause) }
            return .visitChildren
        }

        // A class or an actor, `distributed` ones included, only takes its name.
        override func visit(_ node: ClassDeclSyntax) -> SyntaxVisitorContinueKind {
            collect(node, name: node.name) { nil }
            return .visitChildren
        }

        override func visit(_ node: ActorDeclSyntax) -> SyntaxVisitorContinueKind {
            collect(node, name: node.name) { nil }
            return .visitChildren
        }

        override func visit(_ node: InitializerDeclSyntax) -> SyntaxVisitorContinueKind {
            var ancestor = node.parent
            while let current = ancestor, !current.isProtocol((any DeclGroupSyntax).self) {
                ancestor = current.parent
            }
            if let extensionDeclaration = ancestor?.as(ExtensionDeclSyntax.self) {
                result.typesWithExtensionInitializers.insert(extensionDeclaration.extendedType.trimmedDescription.filter { !$0.isWhitespace })
            }
            return .skipChildren
        }

        override func visit(_ node: EnumDeclSyntax) -> SyntaxVisitorContinueKind {
            collect(node, name: node.name) { Self.firstPlainCase(of: node.memberBlock) }
            return .visitChildren
        }

        // A type declared in a function, an accessor or a closure can't be named by a member.
        override func visit(_ node: CodeBlockSyntax) -> SyntaxVisitorContinueKind { .skipChildren }
        override func visit(_ node: AccessorBlockSyntax) -> SyntaxVisitorContinueKind { .skipChildren }
        override func visit(_ node: ClosureExprSyntax) -> SyntaxVisitorContinueKind { .skipChildren }

        private func collect(_ node: some DeclGroupSyntax, name: TokenSyntax, value: () -> ValueDefault?) {
            var components = [name.text]
            var isPlain = Self.isPlain(Syntax(node))
            var ancestor = node.parent
            while let current = ancestor {
                if current.is(IfConfigDeclSyntax.self) {
                    isPlain = false
                } else if let extensionDeclaration = current.as(ExtensionDeclSyntax.self) {
                    components.insert(extensionDeclaration.extendedType.trimmedDescription.filter { !$0.isWhitespace }, at: 0)
                    isPlain = isPlain && Self.isPlain(current)
                } else if let named = current.asProtocol((any NamedDeclSyntax).self), current.isProtocol((any DeclGroupSyntax).self) {
                    components.insert(named.name.text, at: 0)
                    isPlain = isPlain && Self.isPlain(current)
                }
                ancestor = current.parent
            }
            let qualifiedName = components.joined(separator: ".")
            result.declarations[qualifiedName, default: 0] += 1
            if isPlain, let value = value() {
                result.defaults[qualifiedName] = value
            }
        }

        /// Attributes that change neither a type's isolation nor where it's available.
        private static let plainAttributes: Set<String> = [
            "frozen", "objc", "objcMembers", "dynamicMemberLookup", "dynamicCallable", "propertyWrapper",
            "resultBuilder", "usableFromInline",
        ]

        /// Whether a type or extension is declared without generics, without an attribute that may isolate it or
        /// limit where it's available, and copyable.
        private static func isPlain(_ node: Syntax) -> Bool {
            guard let group = node.asProtocol((any DeclGroupSyntax).self) else { return false }
            let attributesArePlain = group.attributes.allSatisfy { element in
                guard case .attribute(let attribute) = element else { return false }
                return plainAttributes.contains(attribute.attributeName.trimmedDescription)
            }
            let hasGenerics = node.asProtocol((any WithGenericParametersSyntax).self)?.genericParameterClause != nil
                || group.genericWhereClause != nil
            let suppressesAConformance = group.inheritanceClause?.inheritedTypes.contains { $0.type.is(SuppressedTypeSyntax.self) } ?? false
            return attributesArePlain && !hasGenerics && !suppressesAConformance && !node.is(ProtocolDeclSyntax.self)
        }

        /// What a struct may conform to and still have an initializer that runs from any isolation: a protocol of the
        /// sources may isolate it.
        private static let plainInheritedTypes: Set<String> = [
            "Sendable", "Equatable", "Hashable", "Comparable", "Codable", "Encodable", "Decodable", "Identifiable",
            "CustomStringConvertible", "CustomDebugStringConvertible", "Error", "BitwiseCopyable", "SendableMetatype",
        ]

        /// The initializer `Type()` calls on a struct, when it's sure to exist and to run anywhere without failing: an
        /// `init()` the struct declares, its only initializer whose parameters all have defaults, or, when it
        /// declares none, the implicit one of a struct whose stored properties all have defaults. An initializer in
        /// an extension isn't seen here: see ``ValueDefaults/typesWithExtensionInitializers``.
        private static func initializer(of members: MemberBlockSyntax, inheritance: InheritanceClauseSyntax?) -> ValueDefault? {
            let inheritsOnlyPlainTypes = inheritance?.inheritedTypes.allSatisfy { inherited in
                let type = inherited.type.as(AttributedTypeSyntax.self)?.baseType ?? inherited.type
                return plainInheritedTypes.contains(type.trimmedDescription)
            } ?? true
            // A member under `#if` or from a macro may be a stored property or an initializer.
            let hasHiddenMembers = members.members.contains { $0.decl.is(IfConfigDeclSyntax.self) || $0.decl.is(MacroExpansionDeclSyntax.self) }
            guard inheritsOnlyPlainTypes, !hasHiddenMembers else { return nil }

            let initializers = members.members.compactMap { $0.decl.as(InitializerDeclSyntax.self) }
            guard !initializers.isEmpty else {
                let storedPropertiesHaveDefaults = members.members
                    .compactMap { $0.decl.as(VariableDeclSyntax.self) }
                    .allSatisfy(hasDefaultOrIsNotStored)
                return storedPropertiesHaveDefaults ? .initializer(access: .internal) : nil
            }
            let withoutArguments = initializers.filter { $0.signature.parameterClause.parameters.isEmpty }
            let withDefaults = initializers.filter { $0.signature.parameterClause.parameters.allSatisfy { $0.defaultValue != nil } }
            guard let initializer = withoutArguments.first ?? (withDefaults.count == 1 ? withDefaults.first : nil),
                  initializer.attributes.isEmpty, initializer.optionalMark == nil,
                  initializer.signature.effectSpecifiers == nil,
                  initializer.genericParameterClause == nil, initializer.genericWhereClause == nil else { return nil }
            let access = initializer.modifiers.lazy.compactMap { Accessibility(tokenKind: $0.name.tokenKind) }.first ?? .internal
            return access.isAccessible ? .initializer(access: access) : nil
        }

        /// Whether every stored property a declaration introduces has a default value: an initial value, or `nil`
        /// for an optional `var`. A computed, `static` or `class` property stores nothing in an instance.
        private static func hasDefaultOrIsNotStored(_ variable: VariableDeclSyntax) -> Bool {
            let isTypeProperty = variable.modifiers.contains { $0.name.tokenKind == .keyword(.static) || $0.name.tokenKind == .keyword(.class) }
            guard !isTypeProperty else { return true }
            return variable.bindings.allSatisfy { binding in
                if binding.initializer != nil {
                    return true
                }
                if let accessors = binding.accessorBlock?.accessors {
                    // Observers leave the property stored.
                    guard case .accessors(let list) = accessors else { return true }
                    let isComputed = list.contains { ![.keyword(.willSet), .keyword(.didSet)].contains($0.accessorSpecifier.tokenKind) }
                    if isComputed {
                        return true
                    }
                }
                // A property wrapper decides its own default.
                guard variable.bindingSpecifier.tokenKind == .keyword(.var), variable.attributes.isEmpty,
                      let type = binding.typeAnnotation?.type else { return false }
                return type.is(OptionalTypeSyntax.self) || type.is(ImplicitlyUnwrappedOptionalTypeSyntax.self)
            }
        }

        /// The enum's first case without associated values that every build declares and nothing limits.
        private static func firstPlainCase(of members: MemberBlockSyntax) -> ValueDefault? {
            for declaration in members.members.compactMap({ $0.decl.as(EnumCaseDeclSyntax.self) }) where declaration.attributes.isEmpty {
                if let element = declaration.elements.first(where: { $0.parameterClause == nil }) {
                    return .enumCase(element.name.text)
                }
            }
            return nil
        }
    }
}
