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

        let inputPathValues: [Path]
        if module.options.glob {
            inputPathValues = sources.flatMap { Glob(pattern: $0.description).paths.map { Path($0) } }
        } else {
            inputPathValues = sources
        }
        let sortedInputPathValues = Set(inputPathValues.map { $0.standardRawValue }).sorted()

        let inputFiles = sortedInputPathValues
            .map { Path($0) }
            .filter { $0.exists }
            .map(TextFile.init(path:))

        // An attribute isolates a declaration only if it names a global actor, which may be declared in another file.
        let globalActors: Set<String> = await inputFiles
            .concurrentCompactMap { file in
                (try? String(contentsOf: file.path.url, encoding: .utf8)).map(Crawler.globalActorNames(in:))
            }
            .reduce(into: []) { $0.formUnion($1) }

        let files: [FileRepresentation] = await inputFiles.concurrentCompactMap { file in
            do {
                log(.verbose, message: "Processing file: \(file.path)")
                let crawler = try Crawler.crawl(url: file.path.url, globalActors: globalActors)
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
        let finalFiles = if module.options.enableInheritance {
            inheritNSObject(mergingInheritance(flatMappedFiles))
        } else {
            flatMappedFiles
        }

        // filter classes/protocols based on the settings passed to the generator
        var typeFilters: [TokenFilter] = []
        if module.options.protocolsOnly {
            typeFilters.append(ignoreClasses)
        }
        if let regex = module.regex {
            typeFilters.append(try keepMatching(pattern: regex))
        }
        if !module.exclude.isEmpty {
            typeFilters.append(ignoreExcluded(in: module.exclude))
        }
        let parsedFiles = removeTypes(from: finalFiles, using: typeFilters)
        let mockableFiles = parsedFiles.map { $0.replacing(tokens: $0.tokens.filter { $0.isMockable }) }

        let timestamp = verbose ? Date().description : nil
        let sharedPublicModules = singleFileOutput ? publicModules(in: mockableFiles, module: module) : nil
        return try await mockableFiles.concurrentMap { file in
            await GeneratedFile(
                path: file.file.path,
                contents: [
                    module.options.omitHeaders ? nil : FileHeaderHandler.header(for: file, timestamp: timestamp),
                    FileHeaderHandler.imports(for: file, imports: module.imports, publicImports: module.publicImports, testableImports: module.testableImports, publicModules: sharedPublicModules ?? publicModules(in: [file], module: module)),
                    try GeneratorHelper.generate(tokens: file.tokens, keepDocumentation: module.options.keepDocumentation),
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

    private static func inheritNSObject(_ filesRepresentation: [FileRepresentation]) -> [FileRepresentation] {
        func containsRecursively(name: String) -> Bool {
            guard let protocolDeclaration = protocolDeclarationDictionary[name] else { return false }
            let collapsedInheritedTypesName = protocolDeclaration.inheritedTypes
            if collapsedInheritedTypesName.contains(where: { $0 == "NSObjectProtocol" }) {
                return true
            } else {
                return protocolDeclaration.inheritedTypes.contains { inheritanceType in
                    containsRecursively(name: inheritanceType)
                }
            }
        }

        let protocolDeclarationDictionary: [String: ProtocolDeclaration] = Dictionary(
            filesRepresentation.flatMap { file in
                file.tokens.compactMap { token -> (name: String, protocolDeclaration: ProtocolDeclaration)? in
                    guard let protocolDeclaration = token as? ProtocolDeclaration else { return nil }
                    return (name: protocolDeclaration.name, protocolDeclaration: protocolDeclaration)
                }
            }
        ) { former, latter in
            log(.info, message: "Duplicate protocol '\(former.name)' in source set, behavior is undefined.")
            return latter
        }

        let nsObjectProtocols: [ProtocolDeclaration] = protocolDeclarationDictionary.values.reduce(into: []) { protocols, protocolDeclaration in
            guard containsRecursively(name: protocolDeclaration.name) else { return }
            protocols.append(protocolDeclaration)
        }

        return filesRepresentation.map { $0.inheritNSObject(protocols: nsObjectProtocols) }
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

    // filter that keeps the classes/protocols that match the passed regular expression
    private static func keepMatching(pattern: String) throws -> TokenFilter {
        do {
            let regex = try NSRegularExpression(pattern: pattern, options: [])

            return { token in
                guard let namedToken = token as? any HasName else { return true }
                return regex.firstMatch(in: namedToken.name, options: [], range: NSMakeRange(0, namedToken.name.count)) != nil
            }
        } catch {
            throw GeneratorError.invalidRegex(pattern, error: error)
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


