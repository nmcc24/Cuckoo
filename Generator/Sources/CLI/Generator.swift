import Foundation
import Rainbow

final class Generator {
    typealias TokenFilter = (any Token) -> Bool
    
    struct GeneratedFile {
        let path: Path
        let contents: String
    }

    /// - Parameter singleFileOutput: whether the files are joined into one, which then needs one access level per import.
    static func generate(for module: Module, singleFileOutput: Bool, verbose: Bool) async throws -> [GeneratedFile] {
        let sources = module.sources ?? []

        func expand(_ source: Path) -> [Path] {
            module.options.glob ? Glob(pattern: source.description).paths.map { Path($0) } : [source]
        }
        let sortedInputPathValues = Set(sources.flatMap(expand).map { $0.standardRawValue }).sorted()
        // The Swift module of each input file, where it's known: from the table form of `sources`, where a file
        // that two modules' globs match stays with the first, or for the files in its directory, from the plugin.
        let swiftModules = Dictionary(
            sources.flatMap { source in
                expand(source).compactMap { path in
                    (module.swiftModules[source] ?? module.sourceModule.flatMap { $0.contains(path) ? $0.name : nil })
                        .map { (path.standardRawValue, $0) }
                }
            }
        ) { first, _ in first }

        let inputFiles = sortedInputPathValues
            .map { Path($0) }
            .filter { $0.exists }
            .map(TextFile.init(path:))

        // An attribute isolates a declaration only if it names a global actor, and an argument is recorded as a
        // placeholder if its type is `~Copyable`. Either may be declared in another file.
        let scannedFiles = await inputFiles.concurrentCompactMap { file -> (names: Crawler.DeclaredNames, swiftModule: String?, types: [TopLevelType])? in
            guard let source = try? String(contentsOf: file.path.url, encoding: .utf8) else { return nil }
            let swiftModule = swiftModules[file.path.standardRawValue]
            return (Crawler.declaredNames(in: source), swiftModule, swiftModule.map { _ in Crawler.topLevelTypes(in: source) } ?? [])
        }
        let declaredNames = scannedFiles.reduce(into: Crawler.DeclaredNames()) { $0.formUnion($1.names) }
        // Every type the sources of a known module declare, which the generated files import by name.
        let typesByModule = scannedFiles.reduce(into: [String: [TopLevelType]]()) { typesByModule, file in
            guard let swiftModule = file.swiftModule else { return }
            typesByModule[swiftModule, default: []] += file.types
        }

        let files: [FileRepresentation] = await inputFiles.concurrentCompactMap { file in
            do {
                log(.verbose, message: "Processing file: \(file.path)")
                let crawler = try Crawler.crawl(
                    url: file.path.url,
                    globalActors: declaredNames.globalActors,
                    noncopyableTypes: declaredNames.noncopyableTypes
                )
                for diagnostic in crawler.diagnostics {
                    FileHandle.standardError.write(Data("\(diagnostic)\n".utf8))
                }
                log(.verbose, message: "Successfully processed file: \(file.path)")
                return FileRepresentation(file: file, imports: crawler.imports, tokens: crawler.tokens)
            } catch {
                log(.error, message: "Failed to crawl file at '\(file.path)':", error)
                return nil
            }
        }
        let flatMappedFiles = files.map { $0.flatMappingMemberContainers() }
        let inheritedFiles = if module.options.enableInheritance {
            bindingSuperclasses(mergingInheritance(flatMappedFiles))
        } else {
            flatMappedFiles
        }
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

        let timestamp = verbose ? Date().description : nil
        @Sendable func imports(for files: [FileRepresentation]) -> String {
            FileHeaderHandler.imports(
                for: files,
                imports: module.imports,
                publicImports: module.publicImports,
                testableImports: module.testableImports,
                publicModules: publicModules(in: files, module: module),
                typesByModule: typesByModule
            )
        }
        // A single file has every file's imports once, at its top.
        let firstPath = mockableFiles.first?.file.path
        let sharedImports = singleFileOutput ? imports(for: mockableFiles) : nil
        return try await mockableFiles.concurrentMap { file in
            await GeneratedFile(
                path: file.file.path,
                contents: [
                    file.file.path == firstPath ? sharedImports : nil,
                    module.options.omitHeaders ? nil : FileHeaderHandler.header(for: file, timestamp: timestamp),
                    sharedImports == nil ? imports(for: [file]) : nil,
                    try GeneratorHelper.generate(tokens: file.tokens, keepDocumentation: module.options.keepDocumentation, mockNaming: module.options.mockNaming),
                ]
                .compactMap { $0 }
                .joined(separator: "\n\n")
            )
        }
    }

    /// The modules a public mock's declaration can name: Cuckoo, the module of the mocked types, which is one of the
    /// testable imports, and whatever the sources import publicly. Under `InternalImportsByDefault`, a plain import
    /// is internal and a public mock can't use its types. Where no mock is public, every import stays plain, because
    /// a public import that no public declaration uses is a warning.
    private static func publicModules(in files: [FileRepresentation], module: Module) -> Set<String> {
        let hasPublicMocks = files.contains { file in
            file.tokens.contains { token in
                guard let token = token as? any HasAccessibility else { return false }
                return token.accessibility == .public || token.accessibility == .open
            }
        }
        guard hasPublicMocks else { return [] }
        return Set(["Cuckoo"] + module.testableImports + files.flatMap { $0.imports.filter(\.isPublic).map(\.description) })
    }

    private static func mergingInheritance(_ filesRepresentation: [FileRepresentation]) -> [FileRepresentation] {
        filesRepresentation.compactMap { $0.mergingInheritance(with: filesRepresentation) }
    }

    /// Binds every protocol that requires a superclass to it: a class declared in the sources that the protocol
    /// names, as `protocol P: Base` or `where Self: Base`, directly or through another protocol, or `NSObject` for
    /// an `NSObjectProtocol`. The protocol's mock and stub then subclass it.
    private static func bindingSuperclasses(_ filesRepresentation: [FileRepresentation]) -> [FileRepresentation] {
        let tokens = filesRepresentation.flatMap(\.tokens)
        let protocols = Dictionary(tokens.compactMap { $0.asProtocol.map { ($0.name, $0) } }) { former, latter in
            log(.info, message: "Duplicate protocol '\(former.name)' in source set, behavior is undefined.")
            return latter
        }
        let classes = Dictionary(tokens.compactMap { $0.asClass.map { ($0.name, $0) } }) { _, latter in latter }

        func superclass(of name: String, visited: Set<String>) -> (name: String, declaration: ClassDeclaration?)? {
            guard !visited.contains(name), let protocolDeclaration = protocols[name] else { return nil }
            for inheritedType in protocolDeclaration.inheritedTypes {
                if inheritedType == "NSObjectProtocol" {
                    return ("NSObject", nil)
                }
                if let declaration = classes[inheritedType] {
                    return (inheritedType, declaration)
                }
            }
            return protocolDeclaration.inheritedTypes.lazy
                .compactMap { superclass(of: $0, visited: visited.union([name])) }
                .first
        }

        return filesRepresentation.map { file in
            file.replacing(tokens: file.tokens.map { token in
                guard let protocolDeclaration = token.asProtocol,
                      let superclass = superclass(of: protocolDeclaration.name, visited: []) else { return token }
                return protocolDeclaration.replacing(superclass: superclass.name, declaration: superclass.declaration)
            })
        }
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
                return try NSRegularExpression(pattern: pattern, options: [])
            } catch {
                throw GeneratorError.invalidRegex(pattern, error: error)
            }
        }
        return { token in
            guard let namedToken = token as? any HasName else { return true }
            let range = NSRange(namedToken.name.startIndex..., in: namedToken.name)
            return regexes.contains { $0.firstMatch(in: namedToken.name, options: [], range: range) != nil }
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

        var description: String {
            switch self {
            case .invalidRegex(let regex, let error):
                return "Invalid regular expression \"\(regex.bold)\" because \(error.localizedDescription)."
            }
        }
    }
}


