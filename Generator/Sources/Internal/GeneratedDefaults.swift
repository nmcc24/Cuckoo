import SwiftParser
import SwiftSyntax

/// The values a mock builds itself for an unstubbed call, when its return type has no registered default: a new
/// `…Stub` for a protocol mocked in the same module, and for a struct, class, actor or enum of the sources, a
/// value from its initializer without arguments or its first case without associated values.
///
/// A mock names such a value in the call it hands the manager, as it does a tuple's default. Only a type the sources
/// declare and the generator resolves without doubt gets one: a wrong guess wouldn't compile.
struct GeneratedDefaults: Sendable {
    /// The defaults of the mocks being generated.
    @TaskLocal static var current = GeneratedDefaults()

    /// A value of one of the sources' types.
    private struct Value: Sendable {
        /// What follows the type's name: `()`, or `.name` for an enum's case.
        var suffix: String
        /// Whether only a mock of an internal type can build it: the initializer is internal, and nothing else says
        /// the mocks can reach the internals of the type's module.
        var needsInternalMock = false
    }

    /// One file's value defaults, and whether the mocks import its Swift module with `@testable`, where that's known.
    typealias FileValues = (values: Crawler.ValueDefaults, isTestable: Bool?)

    /// The mocked protocols whose stub `init()` creates, by canonical qualified name.
    private var stubbedProtocols: Set<String> = []
    private var values: [String: Value] = [:]
    /// Every type and typealias the sources declare, by qualified name: where a name is looked up.
    private var declaredTypes: Set<String> = []
    private var names = TypeNames(files: [])

    init() {}

    /// - Parameters:
    ///   - files: The module's files with the types it mocks.
    ///   - names: The sources' typealiases and type names.
    ///   - declaredTypes: The sources' types and typealiases, by qualified name.
    ///   - genericTypes: The sources' generic types, by qualified name.
    ///   - fileValues: Each source file's value defaults.
    ///   - defaultIsolation: The isolation of the sources' types that state none.
    init(
        files: [FileRepresentation],
        names: TypeNames,
        declaredTypes: Set<String>,
        genericTypes: Set<String> = [],
        fileValues: [FileValues] = [],
        defaultIsolation: Isolation? = nil
    ) {
        self.names = names
        self.declaredTypes = declaredTypes
        stubbedProtocols = Set(
            files.flatMap(\.tokens)
                .compactMap { $0 as? ProtocolDeclaration }
                .filter(Self.hasDefaultConstructibleStub)
                .map { names.canonical($0.fullyQualifiedName) }
        )

        // A name declared twice, in two files or two `#if` branches, is no single type.
        let declarations = fileValues.reduce(into: [String: Int]()) { counts, file in
            for (name, count) in file.values.declarations {
                counts[names.canonical(name), default: 0] += count
            }
        }
        let genericTypes = Set(genericTypes.map(names.canonical))
        // Under a default isolation, an initializer runs on that actor, which a mock's member may not.
        let initializersAreIsolated = defaultIsolation != nil && defaultIsolation != .nonisolated
        for file in fileValues {
            for (name, value) in file.values.defaults {
                let canonical = names.canonical(name)
                let components = canonical.split(separator: ".")
                // The types it's nested in are the sources' own and not generic, so its name needs no arguments.
                let enclosingTypes = components.indices.dropFirst().map { components.prefix($0).joined(separator: ".") }
                guard declarations[canonical] == 1,
                      enclosingTypes.allSatisfy({ declarations[$0] == 1 && !genericTypes.contains($0) }) else { continue }
                switch value {
                case .enumCase(let name):
                    values[canonical] = Value(suffix: ".\(name)")
                case .initializer(let access):
                    guard !initializersAreIsolated else { continue }
                    if access >= .package || file.isTestable == true {
                        values[canonical] = Value(suffix: "()")
                    } else if file.isTestable == nil {
                        values[canonical] = Value(suffix: "()", needsInternalMock: true)
                    }
                }
            }
        }
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
        guard case .type(let description)? = type, let (name, isExistential) = Self.typeName(description) else { return nil }
        let container = member.parent?.value
        // A generic parameter or an associated type of that name is another type.
        let generics = ((container as? any HasGenerics)?.genericParameters ?? []) + Self.genericParameters(of: member)
        guard !generics.contains(where: { $0.name == name }),
              let scope = (container as? any HasName)?.fullyQualifiedName,
              let resolved = resolve(name, from: scope) else { return nil }
        if stubbedProtocols.contains(resolved) {
            return "\(resolved)Stub()"
        }
        guard !isExistential, let value = values[resolved] else { return nil }
        // A mock of an internal type is compiled where the module's internals are visible.
        let mockIsInternal = ((container as? any HasAccessibility)?.accessibility).map { $0 <= .internal } ?? false
        guard !value.needsInternalMock || mockIsInternal else { return nil }
        // The type as the member writes it, which is how the mock's own signature names it.
        return name + value.suffix
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
