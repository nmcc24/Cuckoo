#if canImport(FoundationEssentials)
import FoundationEssentials
#else
import Foundation
#endif
import SwiftParser
import SwiftSyntax

final class Generator {
    typealias TokenFilter = (any Token) -> Bool
    
    struct GeneratedFile {
        let path: Path
        let contents: String
    }

    /// A module's sources, crawled and filtered down to the files with something to mock.
    private struct PreparedModule: Sendable {
        let module: Module
        let files: [FileRepresentation]
        /// Every type the sources of a known Swift module declare, which the generated files import by name.
        let typesByModule: [String: [TopLevelType]]
        /// The default values the module's mocks build themselves.
        let defaults: GeneratedDefaults

        /// The imports the mocks of `files` need, each once.
        func imports(for files: [FileRepresentation]) -> String {
            FileHeaderHandler.imports(
                for: files,
                imports: module.imports,
                publicImports: module.publicImports,
                testableImports: module.testableImports,
                publicModules: Generator.publicModules(in: files, module: module),
                typesByModule: typesByModule
            )
        }
    }

    /// - Parameter singleFileOutput: whether the files are joined into one, which then needs one access level per import.
    static func generate(for module: Module, singleFileOutput: Bool, verbose: Bool) async throws -> [GeneratedFile] {
        let prepared = try await prepare(module)
        // A single file has every file's imports once, at its top.
        let sharedImports = singleFileOutput ? prepared.imports(for: prepared.files) : nil
        return try await render(prepared, sharedImports: sharedImports, verbose: verbose)
    }

    /// The mocks of several modules joined into one file, as the build plugins and a shared `output` write them. The
    /// imports of all the modules come once, at the top, each module in the strongest form any of them asks for.
    static func generateJoined(for modules: [Module], verbose: Bool) async throws -> String {
        var prepared: [PreparedModule] = []
        for module in modules {
            prepared.append(try await prepare(module))
        }
        let sharedImports = FileHeaderHandler.imports(
            for: prepared.flatMap(\.files),
            imports: OrderedSet(prepared.flatMap(\.module.imports)).values,
            publicImports: OrderedSet(prepared.flatMap(\.module.publicImports)).values,
            testableImports: OrderedSet(prepared.flatMap(\.module.testableImports)).values,
            publicModules: prepared.reduce(into: Set<String>()) { $0.formUnion(publicModules(in: $1.files, module: $1.module)) },
            typesByModule: prepared.reduce(into: [String: [TopLevelType]]()) { typesByModule, module in
                typesByModule.merge(module.typesByModule) { existing, added in existing + added.filter { !existing.contains($0) } }
            }
        )
        var contents: [String] = prepared.contains { !$0.files.isEmpty } ? [sharedImports] : []
        for module in prepared {
            // The shared imports stand in for the module's own, so none are repeated.
            contents += try await render(module, sharedImports: "", verbose: verbose).map(\.contents)
        }
        return contents.joinedByBlankLines()
    }

    /// Each of the module's sources with the files it stands for, a glob's matches, and a warning for each source that
    /// matches none: usually a typo or a moved directory, which would otherwise just leave mocks out. The files a build
    /// plugin passes are used as they are, and aren't checked.
    static func expandSources(of module: Module) -> (sources: [(source: Path, files: [Path])], warnings: [String]) {
        let expanded = (module.sources ?? []).map { source in
            (source: source, files: module.sourcesAreFromPlugin ? [source].filter(\.exists) : Glob(pattern: source.description).paths.map { Path($0) })
        }
        let warnings = module.sourcesAreFromPlugin ? [] : expanded.filter(\.files.isEmpty).map { source, _ in
            "The source '\(source)' of module \(module.name) matches no files."
        }
        return (expanded, warnings)
    }

    private static func prepare(_ module: Module) async throws -> PreparedModule {
        let (expandedSources, warnings) = expandSources(of: module)
        for warning in warnings {
            printToStandardError("warning: cuckoo: \(warning)\n")
        }
        let sortedInputPathValues = Set(expandedSources.flatMap(\.files).map { $0.standardRawValue }).sorted()
        // The Swift module of each input file, where it's known: from the table form of `sources`, where a file
        // that two modules' globs match stays with the first, or for the files in its directory, from the plugin.
        let swiftModules = Dictionary(
            expandedSources.flatMap { source, files in
                files.compactMap { path in
                    (module.swiftModules[source] ?? module.sourceModule.flatMap { $0.contains(path) ? $0.name : nil })
                        .map { (path.standardRawValue, $0) }
                }
            }
        ) { first, _ in first }

        // Each file is read once, for the names it declares and then for its mocks. One that can't be read fails the
        // module, which would otherwise miss its mocks without a word.
        let inputFiles = try await sortedInputPathValues
            .map { Path($0) }
            .filter { $0.exists }
            .map(TextFile.init(path:))
            .concurrentMap { file -> (file: TextFile, source: String) in
                do {
                    return (file, try String(contentsOf: file.path.url, encoding: .utf8))
                } catch {
                    throw GeneratorError.unreadableSource(file.path.rawValue, error: error)
                }
            }

        // An attribute isolates a declaration only if it names a global actor, and an argument is recorded as a
        // placeholder if its type is `~Copyable`. Either may be declared in another file.
        let scannedFiles = await inputFiles.concurrentMap { file, source -> (names: Crawler.DeclaredNames, swiftModule: String?, types: [TopLevelType], values: Crawler.ValueDefaults) in
            let swiftModule = swiftModules[file.path.standardRawValue]
            return (Crawler.declaredNames(in: source), swiftModule, swiftModule.map { _ in Crawler.topLevelTypes(in: source) } ?? [], Crawler.valueDefaults(in: source))
        }
        let declaredNames = scannedFiles.reduce(into: Crawler.DeclaredNames()) { $0.formUnion($1.names) }
        // Every type the sources of a known module declare, which the generated files import by name.
        let typesByModule = scannedFiles.reduce(into: [String: [TopLevelType]]()) { typesByModule, file in
            guard let swiftModule = file.swiftModule else { return }
            typesByModule[swiftModule, default: []] += file.types
        }

        let crawled = await inputFiles.concurrentMap { file, source -> (file: FileRepresentation, unmockedProtocols: Set<String>) in
            log(.verbose, message: "Processing file: \(file.path)")
            let crawler = Crawler.crawl(
                source: source,
                url: file.path.url,
                globalActors: declaredNames.globalActors.union(module.globalActors),
                noncopyableTypes: declaredNames.unconditionallyNoncopyableTypes,
                closureTypealiases: declaredNames.closureTypealiases,
                nonPublicTypes: declaredNames.nonPublicTypes,
                genericTypes: declaredNames.genericTypes,
                qualifiedGenericTypes: declaredNames.qualifiedGenericTypes,
                uncheckedSendableTypes: declaredNames.uncheckedSendableTypes,
                protocolsAndClasses: declaredNames.protocolsAndClasses,
                compositionTypealiases: declaredNames.compositionTypealiases,
                actors: declaredNames.actors,
                privateNames: declaredNames.privateNames,
                nominalTypes: declaredNames.nominalTypes,
                defaultIsolation: module.options.defaultIsolation
            )
            for diagnostic in crawler.diagnostics {
                printToStandardError("\(diagnostic)\n")
            }
            log(.verbose, message: "Successfully processed file: \(file.path)")
            return (FileRepresentation(file: file, imports: crawler.imports, tokens: crawler.tokens), crawler.unmockedProtocols)
        }
        let flatMappedFiles = withoutDescendants(
            of: crawled.reduce(into: Set<String>()) { $0.formUnion($1.unmockedProtocols) },
            in: crawled.map { $0.file.flatMappingMemberContainers() }
        )
        for warning in duplicateDeclarationWarnings(flatMappedFiles) {
            printToStandardError("warning: cuckoo: \(warning)\n")
        }
        let inheritedFiles = mergingAndBinding(flatMappedFiles, typealiases: declaredNames.typealiases, types: declaredNames.publicTypes.union(declaredNames.nonPublicTypes), nominalTypes: declaredNames.nominalTypes)
        let finalFiles = inheritedFiles.map { file in file.replacing(tokens: file.tokens.map { $0.resolvingSelf() }) }

        // filter classes/protocols based on the settings passed to the generator
        var typeFilters: [TokenFilter] = []
        if module.options.protocolsOnly {
            typeFilters.append(ignoreClasses)
        }
        if !module.regexes.isEmpty {
            typeFilters.append(try keepMatching(patterns: module.regexes))
        }
        if !module.exclude.isEmpty {
            typeFilters.append(ignoreExcluded(in: module.exclude))
        }
        let parsedFiles = removeTypes(from: finalFiles, using: typeFilters)
        let mockableFiles = parsedFiles.map { $0.replacing(tokens: $0.tokens.filter { $0.isMockable }) }
        let defaults = GeneratedDefaults(
            files: mockableFiles,
            names: TypeNames(typealiases: declaredNames.typealiases, types: declaredNames.publicTypes.union(declaredNames.nonPublicTypes), files: mockableFiles),
            declaredTypes: declaredNames.nominalTypes.union(declaredNames.typealiases.keys),
            moduleNames: Set(swiftModules.values).union([module.name]),
            genericTypes: declaredNames.qualifiedGenericTypes,
            fileValues: scannedFiles.map { file in (file.values, file.swiftModule.map(module.testableImports.contains)) },
            defaultIsolation: module.options.defaultIsolation
        )
        return PreparedModule(module: module, files: mockableFiles, typesByModule: typesByModule, defaults: defaults)
    }

    /// - Parameter sharedImports: the imports of a single output file, which go at the top of its first file; without
    ///   them, every file has its own.
    private static func render(_ prepared: PreparedModule, sharedImports: String?, verbose: Bool) async throws -> [GeneratedFile] {
        let module = prepared.module
        let timestamp = verbose ? Date().description : nil
        let firstPath = prepared.files.first?.file.path
        return try await prepared.files.concurrentMap { file in
            GeneratedFile(
                path: file.file.path,
                contents: [
                    file.file.path == firstPath && sharedImports?.isEmpty == false ? sharedImports : nil,
                    FileHeaderHandler.header(for: file, relativeTo: module.projectDirectory, timestamp: timestamp),
                    sharedImports == nil ? prepared.imports(for: [file]) : nil,
                    try GeneratorHelper.generate(tokens: file.tokens, keepDocumentation: module.options.keepDocumentation, mockNaming: module.options.mockNaming, defaults: prepared.defaults),
                ]
                .compactMap { $0 }
                .joinedByBlankLines()
            )
        }
    }

    /// The modules a public mock's declaration can name: Cuckoo, the module of the mocked types, which is one of the
    /// testable imports, and whatever the sources import publicly. Under `InternalImportsByDefault`, a plain import
    /// is internal and a public mock can't use its types. Where no mock is public, every import stays plain, because
    /// a public import that no public declaration uses is a warning.
    fileprivate static func publicModules(in files: [FileRepresentation], module: Module) -> Set<String> {
        let hasPublicMocks = files.contains { file in
            file.tokens.contains { token in
                guard let token = token as? any HasAccessibility else { return false }
                return token.accessibility == .public || token.accessibility == .open
            }
        }
        guard hasPublicMocks else { return [] }
        return Set(["Cuckoo"] + module.testableImports + files.flatMap { $0.imports.filter(\.isPublic).map(\.description) })
    }

    /// Two protocols or classes with the same qualified name, neither under `#if`, get two mocks of the same name,
    /// which don't compile together. That happens when an entry's sources span modules or folders that each declare
    /// the type. The warning names the files, so the build's "invalid redeclaration" has an explanation.
    /// The files without the protocols that refine an unmocked one, directly or through others: their mocks would
    /// have to implement the requirement that left it out. Each gets a warning naming the protocol it refines.
    private static func withoutDescendants(of unmocked: Set<String>, in files: [FileRepresentation]) -> [FileRepresentation] {
        var unmocked = unmocked
        var changed = !unmocked.isEmpty
        while changed {
            changed = false
            for protocolToken in files.flatMap(\.tokens).compactMap({ $0 as? ProtocolDeclaration }) where !unmocked.contains(protocolToken.name) {
                guard let parent = protocolToken.inheritedTypes.map(\.withoutGenericArguments).first(where: unmocked.contains) else { continue }
                unmocked.insert(protocolToken.name)
                changed = true
                printToStandardError("warning: cuckoo: '\(protocolToken.name)' isn't mocked: it refines '\(parent)', which isn't mocked.\n")
            }
        }
        return files.map { file in
            file.replacing(tokens: file.tokens.filter { ($0 as? ProtocolDeclaration).map { !unmocked.contains($0.name) } ?? true })
        }
    }

    static func duplicateDeclarationWarnings(_ files: [FileRepresentation]) -> [String] {
        var firstFiles: [String: Path] = [:]
        var warnings: [String] = []
        for file in files {
            for token in file.tokens where token.isClass || token.isProtocol {
                guard let named = token as? any Token & HasName,
                      (token as? any HasAttributes)?.hasCompilationCondition != true,
                      (token as? any HasEnclosingCompilationConditions)?.enclosingCompilationConditions.isEmpty != false else { continue }
                if let first = firstFiles[named.fullyQualifiedName] {
                    warnings.append("'\(named.fullyQualifiedName)' is declared in \(first) and in \(file.file.path), so their mocks have the same name and don't compile together. List only one of them in the module's `sources`.")
                } else {
                    firstFiles[named.fullyQualifiedName] = file.file.path
                }
            }
        }
        return warnings
    }

    /// The files with each protocol and class merged with what it inherits, then each protocol bound to the class
    /// it requires, both resolved by scope as Swift does.
    private static func mergingAndBinding(_ files: [FileRepresentation], typealiases: [String: String], types: Set<String>, nominalTypes: Set<String>) -> [FileRepresentation] {
        let merged = files.map { $0.mergingInheritance(with: files, names: TypeNames(typealiases: typealiases, types: types, files: files)) }
        return bindingSuperclasses(merged, names: TypeNames(typealiases: typealiases, types: types, files: merged), nominalTypes: nominalTypes)
    }

    /// Binds every protocol that requires a superclass to it: a class declared in the sources that the protocol
    /// names, as `protocol P: Base` or `where Self: Base`, directly or through another protocol, or `NSObject` for
    /// an `NSObjectProtocol`. The protocol's mock and stub then subclass it.
    /// A generic class's arguments are qualified from the scope of the protocol that wrote them: merging inheritance
    /// leaves each protocol's `inheritedTypes` as it declared them.
    private static func bindingSuperclasses(_ filesRepresentation: [FileRepresentation], names: TypeNames, nominalTypes: Set<String>) -> [FileRepresentation] {
        func superclass(of protocolDeclaration: ProtocolDeclaration, visited: Set<String>) -> (name: String, declaration: ClassDeclaration?)? {
            guard !visited.contains(protocolDeclaration.fullyQualifiedName) else { return nil }
            // A generic class is bound with the arguments it's written with, `: Gen<Int>`, and found by its name.
            let parents = protocolDeclaration.inheritedTypes.map { inheritedType in
                let name = inheritedType.firstIndex(of: "<").map { String(inheritedType[..<$0]) } ?? inheritedType
                let arguments = String(inheritedType.dropFirst(name.count))
                return (inheritedType, names.resolve(name, from: protocolDeclaration.fullyQualifiedName), arguments)
            }
            for (inheritedType, resolved, arguments) in parents {
                if inheritedType == "NSObjectProtocol" {
                    return ("NSObject", nil)
                }
                // Named by its qualified name, which reads the same from wherever the mock is: a parent protocol
                // may have named it relative to its own scope.
                if let declaration = resolved as? ClassDeclaration {
                    // Canonical, so `extension App.Outer` scopes to `Outer`.
                    let scope = names.canonical(protocolDeclaration.fullyQualifiedName).split(separator: ".").dropLast().map(String.init)
                    let typeNames = nominalTypes.union(names.typealiases.keys)
                    return (declaration.fullyQualifiedName + qualifying(arguments, in: scope, nominalTypes: typeNames), declaration)
                }
            }
            return parents.lazy
                .compactMap { $0.1 as? ProtocolDeclaration }
                .compactMap { superclass(of: $0, visited: visited.union([protocolDeclaration.fullyQualifiedName])) }
                .first
        }

        return filesRepresentation.map { file in
            file.replacing(tokens: file.tokens.map { token in
                guard let protocolDeclaration = token.asProtocol,
                      let superclass = superclass(of: protocolDeclaration, visited: []) else { return token }
                return protocolDeclaration.replacing(superclass: superclass.name, declaration: superclass.declaration)
            })
        }
    }

    /// Generic arguments, `<Item>`, written in `scope`, with each type or typealias they name from that scope written qualified,
    /// so they read the same in the mock: `<Item>` in `NS` is `<NS.Item>`.
    private static func qualifying(_ arguments: String, in scope: [String], nominalTypes: Set<String>) -> String {
        guard !arguments.isEmpty, !scope.isEmpty else { return arguments }
        final class Qualifier: SyntaxRewriter {
            let scope: [String]
            let nominalTypes: Set<String>
            init(scope: [String], nominalTypes: Set<String>) {
                self.scope = scope
                self.nominalTypes = nominalTypes
            }
            override func visit(_ node: IdentifierTypeSyntax) -> TypeSyntax {
                for length in stride(from: scope.count, through: 1, by: -1) {
                    let qualified = (scope.prefix(length) + [node.name.text]).joined(separator: ".")
                    if nominalTypes.contains(qualified) {
                        let arguments = node.genericArgumentClause.map { rewrite(Syntax($0)).trimmedDescription } ?? ""
                        var parser = Parser(qualified + arguments)
                        return TypeSyntax.parse(from: &parser)
                    }
                }
                return super.visit(node)
            }
        }
        // Parsed as the arguments of a placeholder type, which names nothing in the module.
        let placeholder = "__CuckooArguments"
        var parser = Parser(placeholder + arguments)
        let rewritten = Qualifier(scope: scope, nominalTypes: nominalTypes).rewrite(TypeSyntax.parse(from: &parser)).trimmedDescription
        return String(rewritten.dropFirst(placeholder.count))
    }

    private static func removeTypes(from files: [FileRepresentation], using filters: [TokenFilter]) -> [FileRepresentation] {
        // Only keep those that pass all filters
        let filter: TokenFilter = { token in
            guard token.isClass || token.isProtocol else { return true }
            return !filters.contains { !$0(token) }
        }

        return files.compactMap { file in
            let filteredTokens = file.tokens.filter(filter)
            guard !filteredTokens.isEmpty else { return nil }
            return file.replacing(tokens: filteredTokens)
        }
    }

    // filter that keeps the protocols while removing all classes
    private static func ignoreClasses(token: any Token) -> Bool {
        !token.isClass
    }

    // filter that keeps the classes/protocols whose name matches any of the passed regular expressions
    private static func keepMatching(patterns: [String]) throws -> TokenFilter {
        let regexes = try patterns.map { pattern in
            do {
                return try Regex(pattern).wordBoundaryKind(.simple)
            } catch {
                throw GeneratorError.invalidRegex(pattern, error: error)
            }
        }
        return { token in
            guard let namedToken = token as? any HasName else { return true }
            return regexes.contains { namedToken.name.contains($0) }
        }
    }

    // filter that keeps only the classes/protocols that are not supposed to be excluded
    private static func ignoreExcluded(in excluded: [String]) -> TokenFilter {
        let excludedSet = Set(excluded)
        return { token in
            guard let containerToken = token as? any ContainerToken else { return true }
            return !excludedSet.contains(containerToken.name)
        }
    }

    enum GeneratorError: Error, CustomStringConvertible {
        case invalidRegex(String, error: any Error)
        case unreadableSource(String, error: any Error)

        var description: String {
            switch self {
            case .invalidRegex(let regex, let error):
                return "Invalid regular expression \"\(regex)\" because \(error)."
            case .unreadableSource(let path, let error):
                return "Failed to read the source file at '\(path)': \(error)"
            }
        }
    }
}


