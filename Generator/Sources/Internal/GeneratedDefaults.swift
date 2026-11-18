import SwiftParser
import SwiftSyntax

/// The values a mock builds itself for an unstubbed call, when its return type has no registered default: a new
/// `…Stub` for a protocol mocked in the same module.
///
/// A mock names such a value in the call it hands the manager, as it does a tuple's default. Only a type the sources
/// declare and the generator resolves without doubt gets one: a wrong guess wouldn't compile.
struct GeneratedDefaults: Sendable {
    /// The defaults of the mocks being generated.
    @TaskLocal static var current = GeneratedDefaults()

    /// The mocked protocols whose stub `init()` creates, by canonical qualified name.
    private var stubbedProtocols: Set<String> = []
    /// Every type and typealias the sources declare, by qualified name: where a name is looked up.
    private var declaredTypes: Set<String> = []
    private var names = TypeNames(files: [])

    init() {}

    /// - Parameters:
    ///   - files: The module's files with the types it mocks.
    ///   - names: The sources' typealiases and type names.
    ///   - declaredTypes: The sources' types and typealiases, by qualified name.
    init(files: [FileRepresentation], names: TypeNames, declaredTypes: Set<String>) {
        self.names = names
        self.declaredTypes = declaredTypes
        stubbedProtocols = Set(
            files.flatMap(\.tokens)
                .compactMap { $0 as? ProtocolDeclaration }
                .filter(Self.hasDefaultConstructibleStub)
                .map { names.canonical($0.fullyQualifiedName) }
        )
    }

    /// Whether `Stub()` creates the protocol's stub wherever its mocks are: it isn't generic, takes no initializer
    /// from a requirement or a superclass, and is declared whenever the code that names the protocol is.
    private static func hasDefaultConstructibleStub(_ declaration: ProtocolDeclaration) -> Bool {
        !declaration.isGeneric
            && declaration.mockedInitializers.isEmpty
            && (declaration.superclass ?? "").isEmpty
            && declaration.attributes.isEmpty
            && declaration.enclosingCompilationConditions.isEmpty
            && declaration.accessibility.isAccessible
    }

    /// The expression that builds the default of `member`'s return type `type`, or nil when it has none.
    func expression(for type: ComplexType?, of member: any Token) -> String? {
        guard case .type(let description)? = type, let (name, _) = Self.typeName(description) else { return nil }
        let container = member.parent?.value
        // A generic parameter or an associated type of that name is another type.
        let generics = ((container as? any HasGenerics)?.genericParameters ?? []) + Self.genericParameters(of: member)
        guard !generics.contains(where: { $0.name == name }),
              let scope = (container as? any HasName)?.fullyQualifiedName,
              let resolved = resolve(name, from: scope) else { return nil }
        if stubbedProtocols.contains(resolved) {
            return "\(resolved)Stub()"
        }
        return nil
    }

    private static func genericParameters(of member: any Token) -> [GenericParameter] {
        (member as? Method)?.signature.genericParameters ?? (member as? Subscript)?.genericParameters ?? []
    }

    /// The qualified name of the type `name` refers to from inside `scope`, found as Swift finds it: in the innermost
    /// enclosing scope that declares the name, through typealiases. Nil for a name the sources don't declare.
    private func resolve(_ name: String, from scope: String) -> String? {
        let components = name.split(separator: ".").map(String.init)
        var enclosing = names.canonical(scope).split(separator: ".").map(String.init)
        while true {
            // The first component decides which declaration the name is; the rest are its members.
            if declaredTypes.contains((enclosing + components.prefix(1)).joined(separator: ".")) {
                return names.canonical((enclosing + components).joined(separator: "."))
            }
            guard !enclosing.isEmpty else { break }
            enclosing.removeLast()
        }
        // A name the scopes don't declare may start with its module's.
        let canonical = names.canonical(name)
        return canonical != name && declaredTypes.contains(canonical) ? canonical : nil
    }

    /// The name of a plain named type, `Service` or `Feature.Service`, and whether it's written as an existential,
    /// `any Service`. Nil for any other type: an optional, a generic type, a composition, a metatype.
    static func typeName(_ description: String) -> (name: String, isExistential: Bool)? {
        var parser = Parser(description)
        var type = TypeSyntax.parse(from: &parser)
        guard !type.hasError, type.trimmedDescription == description.trimmed else { return nil }
        var isExistential = false
        if let existential = type.as(SomeOrAnyTypeSyntax.self) {
            guard existential.someOrAnySpecifier.tokenKind == .keyword(.any) else { return nil }
            isExistential = true
            type = existential.constraint
        }
        guard isPlainName(type) else { return nil }
        return (type.trimmedDescription.filter { !$0.isWhitespace }, isExistential)
    }

    /// Whether `type` is identifiers joined by dots, with no generic arguments and no raw identifiers.
    private static func isPlainName(_ type: TypeSyntax) -> Bool {
        if let identifier = type.as(IdentifierTypeSyntax.self) {
            return identifier.genericArgumentClause == nil && isPlain(identifier.name)
        }
        if let member = type.as(MemberTypeSyntax.self) {
            return member.genericArgumentClause == nil && isPlain(member.name) && isPlainName(member.baseType)
        }
        return false
    }

    private static func isPlain(_ name: TokenSyntax) -> Bool {
        if case .identifier(let text) = name.tokenKind {
            return !text.hasPrefix("`")
        }
        return false
    }
}
