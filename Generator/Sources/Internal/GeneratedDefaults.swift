import SwiftParser
import SwiftSyntax

/// The values a mock builds itself for an unstubbed call, when its return type has no registered default: a new
/// `…Stub` for a protocol mocked in the same module, and for a struct or an enum of the sources, a value from its
/// initializer without arguments or its first case without associated values.
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
    /// The mocked protocols and classes, by canonical qualified name: each has a `…Stub` next to it.
    private var mockedTypes: Set<String> = []
    /// The names a type of the sources may be qualified with: the Swift modules of the sources, where they're known,
    /// and the Cuckoofile module's.
    private var moduleNames: Set<String> = []
    private var names = TypeNames(files: [])

    init() {}

    /// - Parameters:
    ///   - files: The module's files with the types it mocks.
    ///   - names: The sources' typealiases and type names.
    ///   - declaredTypes: The sources' types and typealiases, by qualified name.
    ///   - moduleNames: The names of the sources' own modules.
    ///   - genericTypes: The sources' generic types, by qualified name.
    ///   - fileValues: Each source file's value defaults.
    ///   - defaultIsolation: The isolation of the sources' types that state none.
    init(
        files: [FileRepresentation],
        names: TypeNames,
        declaredTypes: Set<String>,
        moduleNames: Set<String> = [],
        genericTypes: Set<String> = [],
        fileValues: [FileValues] = [],
        defaultIsolation: Isolation? = nil
    ) {
        self.names = names
        self.declaredTypes = declaredTypes
        self.moduleNames = moduleNames
        let containers = files.flatMap(\.tokens).compactMap { $0 as? any ContainerToken }
        mockedTypes = Set(containers.map { canonical($0.fullyQualifiedName) })
        stubbedProtocols = Set(
            containers
                .compactMap { $0 as? ProtocolDeclaration }
                .filter(Self.hasDefaultConstructibleStub)
                .map { canonical($0.fullyQualifiedName) }
        )

        // A name declared twice, in two files or two `#if` branches, is no single type.
        let declarations = fileValues.reduce(into: [String: Int]()) { counts, file in
            for (name, count) in file.values.declarations {
                counts[canonical(name), default: 0] += count
            }
        }
        let genericTypes = Set(genericTypes.map(canonical))
        // An initializer in an extension can make `Type()` ambiguous, or be the one it calls.
        let typesWithExtensionInitializers = Set(fileValues.flatMap(\.values.typesWithExtensionInitializers).map(canonical))
        // Under a default isolation, an initializer runs on that actor, which a mock's member may not.
        let initializersAreIsolated = defaultIsolation != nil && defaultIsolation != .nonisolated
        for file in fileValues {
            for (name, value) in file.values.defaults {
                let key = canonical(name)
                let components = key.split(separator: ".")
                // The types it's nested in are the sources' own and not generic, so its name needs no arguments.
                let enclosingTypes = components.indices.dropFirst().map { components.prefix($0).joined(separator: ".") }
                guard declarations[key] == 1,
                      enclosingTypes.allSatisfy({ declarations[$0] == 1 && !genericTypes.contains($0) }) else { continue }
                switch value {
                case .enumCase(let name):
                    values[key] = Value(suffix: ".\(name)")
                case .initializer(let access):
                    guard !initializersAreIsolated, !typesWithExtensionInitializers.contains(key) else { continue }
                    if access >= .package || file.isTestable == true {
                        values[key] = Value(suffix: "()")
                    } else if file.isTestable == nil {
                        values[key] = Value(suffix: "()", needsInternalMock: true)
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
            // The stub is named from the top level, where another declaration nearer to the mock mustn't be found.
            let stub = "\(resolved)Stub"
            return isShadowed(stub, from: scope) ? nil : "\(stub)()"
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
        var enclosing = canonical(scope).split(separator: ".").map(String.init)
        while true {
            // The first component decides which declaration the name is; the rest are its members.
            if declaredTypes.contains((enclosing + components.prefix(1)).joined(separator: ".")) {
                return names.canonical((enclosing + components).joined(separator: "."))
            }
            guard !enclosing.isEmpty else { break }
            enclosing.removeLast()
        }
        // A name the scopes don't declare may start with the sources' module, `App.Service`. Any other module's
        // type, `Foundation.Notification`, isn't the sources' type of that name.
        guard components.count > 1, moduleNames.contains(components[0]), declaredTypes.contains(components[1]) else { return nil }
        return names.canonical(components.dropFirst().joined(separator: "."))
    }

    /// `name` without the sources' module it's qualified with, and with its typealiases replaced by their types.
    /// A name that starts with anything else the sources don't declare is left as it is.
    private func canonical(_ name: String) -> String {
        var components = name.split(separator: ".")
        if components.count > 1, moduleNames.contains(String(components[0])), !declaredTypes.contains(String(components[0])) {
            components.removeFirst()
        }
        guard let first = components.first, declaredTypes.contains(String(first)) else { return components.joined(separator: ".") }
        return names.canonical(components.joined(separator: "."))
    }

    /// Whether `name`, a qualified name read from the top level, finds another declaration from inside `scope`: a
    /// type of the sources, or a mocked type's stub, nested in one of the scopes and named as its first component.
    private func isShadowed(_ name: String, from scope: String) -> Bool {
        guard let first = name.split(separator: ".").first.map(String.init) else { return false }
        let stubSuffix = "Stub"
        var enclosing = canonical(scope).split(separator: ".").map(String.init)
        while !enclosing.isEmpty {
            let nested = (enclosing + [first]).joined(separator: ".")
            if declaredTypes.contains(nested) || (first.hasSuffix(stubSuffix) && mockedTypes.contains(String(nested.dropLast(stubSuffix.count)))) {
                return true
            }
            enclosing.removeLast()
        }
        return false
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
