import Foundation
import Rainbow

final class Module: Sendable {
    let name: String
    let imports: [String]
    let publicImports: [String]
    let testableImports: [String]
    let sources: [Path]?
    /// The Swift module each of `sources` belongs to, from the table form of `sources`.
    let swiftModules: [Path: String]
    /// The Swift module the build plugin generates for, which the files in its directory belong to.
    let sourceModule: SourceModule?
    let exclude: [String]
    /// Patterns a type's name must match one of to be mocked. Empty mocks every type.
    let regexes: [String]
    let output: String
    let filenameFormat: String?
    let options: Options

    /// - Parameter sourceModule: The Swift module the build plugin generates for. The table form of `sources`
    ///   names the modules explicitly instead.
    init(
        name: String,
        output: String?,
        overriddenOutput: String? = nil,
        sourceModule: SourceModule? = nil,
        configurationPath: Path,
        dto: DTO
    ) throws {
        if let xcodeproj = dto.xcodeproj {
            throw ModuleInitError.xcodeprojRemoved(name: name, target: xcodeproj.target)
        }

        guard overriddenOutput != nil || output != nil || dto.output != nil else {
            throw ModuleInitError.missingOutput(name: name)
        }

        self.name = name
        self.imports = dto.imports?.map(\.trimmed) ?? []
        self.publicImports = dto.publicImports?.map(\.trimmed) ?? []
        self.testableImports = dto.testableImports?.map(\.trimmed) ?? []
        func path(_ source: String) -> Path {
            Path(source.trimmed, expandingTilde: true).relative(to: configurationPath.parent)
        }
        switch dto.sources {
        case nil:
            self.sources = nil
            self.swiftModules = [:]
            self.sourceModule = sourceModule
        case .paths(let paths)?:
            self.sources = paths.map(path)
            self.swiftModules = [:]
            self.sourceModule = sourceModule
        case .byModule(let pathsByModule)?:
            let sources = pathsByModule.sorted { $0.key < $1.key }.flatMap { module, paths in paths.map { (path($0), module.trimmed) } }
            self.sources = sources.map(\.0)
            self.swiftModules = Dictionary(sources) { first, _ in first }
            self.sourceModule = nil
        }
        self.exclude = dto.exclude?.map(\.trimmed) ?? []
        self.regexes = dto.regex?.values ?? []
        self.output = (overriddenOutput ?? dto.output ?? output)!
        self.filenameFormat = dto.filenameFormat
        self.options = Options(
            glob: dto.options?.glob ?? true,
            keepDocumentation: dto.options?.keepDocumentation ?? true,
            enableInheritance: dto.options?.enableInheritance ?? true,
            protocolsOnly: dto.options?.protocolsOnly ?? false,
            omitHeaders: dto.options?.omitHeaders ?? false,
            mockNaming: MockNaming(
                prefix: dto.options?.mockPrefix?.trimmed ?? MockNaming.default.prefix,
                suffix: dto.options?.mockSuffix?.trimmed ?? MockNaming.default.suffix
            ),
            defaultIsolation: try Self.defaultIsolation(dto.options?.defaultIsolation, moduleName: name)
        )

        if let filenameFormat, !filenameFormat.contains("{}") {
            throw ModuleInitError.wrongFilenameFormat
        }
        try Self.validate(options.mockNaming, moduleName: name)
    }

    /// `defaultIsolation` takes the values SwiftPM's and Xcode's default-isolation settings do.
    private static func defaultIsolation(_ value: String?, moduleName: String) throws -> Isolation? {
        switch value?.trimmed {
        case nil, "nonisolated":
            nil
        case "MainActor":
            .globalActor("MainActor")
        case let value?:
            throw ModuleInitError.invalidDefaultIsolation(name: moduleName, value: value)
        }
    }

    /// The mock's name must be a different identifier from the mocked type's, and from the `<Type>Stub` class
    /// generated next to it.
    private static func validate(_ naming: MockNaming, moduleName: String) throws {
        let identifierCharacters = { (text: String) in
            text.allSatisfy { $0 == "_" || $0.isLetter || $0.isNumber }
        }
        guard identifierCharacters(naming.prefix), identifierCharacters(naming.suffix),
              naming.prefix.first?.isNumber != true else {
            throw ModuleInitError.invalidMockNaming(name: moduleName, reason: "`mockPrefix` and `mockSuffix` may only contain letters, digits and underscores, and `mockPrefix` can't start with a digit.")
        }
        guard !naming.prefix.isEmpty || !naming.suffix.isEmpty else {
            throw ModuleInitError.invalidMockNaming(name: moduleName, reason: "`mockPrefix` and `mockSuffix` can't both be empty, or each mock would have its mocked type's name.")
        }
        guard !(naming.prefix.isEmpty && naming.suffix == "Stub") else {
            throw ModuleInitError.invalidMockNaming(name: moduleName, reason: "`mockSuffix = \"Stub\"` without a prefix gives mocks the name of the `<Type>Stub` classes Cuckoo generates next to them.")
        }
    }

    struct Options {
        let glob: Bool
        let keepDocumentation: Bool
        let enableInheritance: Bool
        let protocolsOnly: Bool
        let omitHeaders: Bool
        let mockNaming: MockNaming
        /// The isolation of the sources' types that don't state one, as the module's `defaultIsolation` setting
        /// gives them. `nil` is `nonisolated`, Swift's default.
        let defaultIsolation: Isolation?
    }

    enum ModuleInitError: Error, CustomStringConvertible {
        case missingOutput(name: String)
        case wrongFilenameFormat
        case xcodeprojRemoved(name: String, target: String?)
        case invalidMockNaming(name: String, reason: String)
        case invalidDefaultIsolation(name: String, value: String)

        var description: String {
            switch self {
            case .missingOutput(let moduleName):
                return "Missing `output` parameter in module \(moduleName). Either define a global `output` or add `output` to the module."
            case .wrongFilenameFormat:
                return "Filename format must contain \"{}\" to denote where to put the base filename."
            case .xcodeprojRemoved(let name, let target):
                let folder = target ?? name
                let reading = target.map { " (it read the files of target \($0))" } ?? ""
                return """
                The `xcodeproj` option was removed in Cuckoo 3. List module \(name)'s files with `sources` instead, \
                e.g. `sources = ["\(folder)/**/*.swift"]`\(reading).
                """
            case .invalidMockNaming(let name, let reason):
                return "Invalid mock naming in module \(name): \(reason)"
            case .invalidDefaultIsolation(let name, let value):
                return "Invalid `defaultIsolation = \"\(value)\"` in module \(name): use \"MainActor\" or \"nonisolated\", as the module's own default isolation."
            }
        }
    }
}

extension Module {
    /// A Swift module and the directory of its sources. A file elsewhere, which a Cuckoofile module may also
    /// list, belongs to another module.
    struct SourceModule: Sendable {
        let name: String
        let directory: Path

        func contains(_ file: Path) -> Bool {
            file.standardRawValue.hasPrefix(directory.standardRawValue + "/")
        }
    }
}

extension Module {
    struct DTO: Decodable {
        let imports: [String]?
        let publicImports: [String]?
        let testableImports: [String]?
        let sources: Sources?
        let exclude: [String]?
        let regex: Patterns?
        let output: String?
        let filenameFormat: String?
        let options: Options?
        let xcodeproj: Xcodeproj?

        struct Options: Decodable {
            let glob: Bool?
            let keepDocumentation: Bool?
            let enableInheritance: Bool?
            let protocolsOnly: Bool?
            let omitHeaders: Bool?
            let mockPrefix: String?
            let mockSuffix: String?
            let defaultIsolation: String?
        }

        /// `sources`: an array of paths, or a table of them by the Swift module they belong to, e.g.
        /// `{ App = ["App/**/*.swift"], Core = ["Core/**/*.swift"] }`.
        enum Sources: Decodable {
            case paths([String])
            case byModule([String: [String]])

            init(from decoder: any Decoder) throws {
                if var list = try? decoder.unkeyedContainer() {
                    var paths: [String] = []
                    while !list.isAtEnd {
                        paths.append(try list.decode(String.self))
                    }
                    self = .paths(paths)
                    return
                }
                let table = try decoder.container(keyedBy: ModuleKey.self)
                self = .byModule(try Dictionary(uniqueKeysWithValues: table.allKeys.map { key in
                    (key.stringValue, try table.decode([String].self, forKey: key))
                }))
            }

            private struct ModuleKey: CodingKey {
                let stringValue: String
                var intValue: Int? { nil }

                init(stringValue: String) {
                    self.stringValue = stringValue
                }

                init?(intValue: Int) {
                    nil
                }
            }
        }

        /// `regex`: one pattern, or an array of them.
        struct Patterns: Decodable {
            let values: [String]

            init(from decoder: any Decoder) throws {
                if let pattern = try? decoder.singleValueContainer().decode(String.self) {
                    values = [pattern]
                    return
                }
                var patterns = try decoder.unkeyedContainer()
                var values: [String] = []
                while !patterns.isAtEnd {
                    values.append(try patterns.decode(String.self))
                }
                self.values = values
            }
        }

        /// The `xcodeproj` table Cuckoo 2 read a target's files from. It's still decoded, so a
        /// leftover one is reported instead of silently generating nothing.
        struct Xcodeproj: Decodable {
            let target: String?
        }
    }
}

extension Module: CustomDebugStringConvertible {
    var debugDescription: String {
        [
            "imports:\(imports.map { "\n\t-\($0.bold)" }.joined(separator: ", "))",
            "public imports:\(publicImports.map { "\n\t-\($0.bold)" }.joined(separator: ", "))",
            "testable imports:\(testableImports.map { "\n\t-\($0.bold)" }.joined(separator: ", "))",
            sources.map { "sources:\($0.map { "\n\t-\($0.rawValue.bold)" }.joined())" },
            "excluded types:\(exclude.map { "\n\t-\($0.bold)" }.joined())",
            regexes.isEmpty ? nil : "regex:\(regexes.map { "\n\t-\($0.bold)" }.joined())",
            "output: \(output.bold)",
            filenameFormat.map { "filename format: \($0.bold)" },
            "options:\(options.debugDescription.components(separatedBy: "\n").map { "\n\t- \($0)" }.joined())",
        ]
        .compactMap { $0 }
        .joined(separator: "\n")
    }
}

extension Module.Options: CustomDebugStringConvertible {
    var debugDescription: String {
        [
            "glob: \(String(glob).bold)",
            "keep documentation: \(String(keepDocumentation).bold)",
            "enable inheritance: \(String(enableInheritance).bold)",
            "protocols only: \(String(protocolsOnly).bold)",
            "omit headers: \(String(omitHeaders).bold)",
            "mock prefix: \(mockNaming.prefix.bold)",
            "mock suffix: \(mockNaming.suffix.bold)",
        ]
        .compactMap { $0 }
        .joined(separator: "\n")
    }
}
