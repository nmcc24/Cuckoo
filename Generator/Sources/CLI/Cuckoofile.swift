import TOMLDecoder

/// Reads `Cuckoofile.toml` into the modules to generate.
enum Cuckoofile {
    /// The top level of `Cuckoofile.toml`.
    private struct File: Decodable {
        /// The output of modules that don't set their own.
        let output: String?
        let modules: [String: Module.DTO]?
    }

    /// - Parameters:
    ///   - contents: The Cuckoofile's text.
    ///   - configurationPath: Where the Cuckoofile is; relative paths in it resolve against its folder.
    ///   - overriddenOutput: An output path that replaces every module's and the global output (the build plugins set it).
    ///   - requestedModuleName: If set, only the module with this name is returned.
    ///   - sourceModule: The Swift module the build plugin generates for, and its directory. A module that names
    ///     modules in `sources` keeps its own.
    ///   - pluginSources: The source files the build plugin passes with `--sources-list`, which modules without
    ///     `sources` mock.
    static func modules(
        from contents: String,
        configurationPath: Path,
        overriddenOutput: String?,
        requestedModuleName: String?,
        sourceModule: Module.SourceModule? = nil,
        pluginSources: [Module.PluginSource]? = nil
    ) throws -> [Module] {
        let file: File
        do {
            file = try TOMLDecoder().decode(File.self, from: contents)
        } catch {
            throw ParseError.unreadable(error)
        }

        var errorMessages: [String] = []
        var allModules: [Module] = []
        // Sorted, so modules are always generated in the same order.
        for (moduleName, dto) in (file.modules ?? [:]).sorted(by: { $0.key < $1.key }) {
            do {
                let module = try Module(
                    name: moduleName,
                    output: file.output,
                    overriddenOutput: overriddenOutput,
                    sourceModule: sourceModule,
                    pluginSources: pluginSources,
                    configurationPath: configurationPath,
                    dto: dto
                )
                log(.verbose, message: "Module \(moduleName):", module)
                allModules.append(module)
            } catch {
                errorMessages.append(String(describing: error))
            }
        }

        guard errorMessages.isEmpty else {
            throw ParseError.configurationErrors(details: errorMessages)
        }

        if let requestedModuleName {
            return allModules.filter { $0.name == requestedModuleName }
        }
        return allModules
    }

    /// Warnings for keys the Cuckoofile has but Cuckoo doesn't read, such as a misspelled `testableImport` or a
    /// `[module.App]` table, which would otherwise be ignored without a word, and for a Cuckoofile that defines no
    /// modules at all. With `module`, a module's keys are checked only for that module: the plugins run the
    /// generator once per module, and each run would repeat every other module's warnings.
    static func warnings(for contents: String, module requestedModule: String? = nil) -> [String] {
        guard let file = try? TOMLTable(source: contents) else { return [] }
        func table(_ parent: TOMLTable, _ key: String) -> TOMLTable? {
            try? parent.table(forKey: key)
        }
        var warnings: [String] = []
        for key in file.keys.sorted() where key != "output" && key != "modules" {
            warnings.append(unknownKey(key, known: ["output", "modules"]))
        }
        let modules = table(file, "modules")
        for moduleName in (modules?.keys ?? []).sorted() where requestedModule.map({ $0 == moduleName }) ?? true {
            guard let module = modules.flatMap({ table($0, moduleName) }) else { continue }
            for moduleKey in module.keys.sorted() where !moduleKeys.contains(moduleKey) {
                warnings.append(optionKeys.contains(moduleKey)
                    ? "The Cuckoofile key 'modules.\(moduleName).\(moduleKey)' is an option, so it's ignored here: "
                        + "put it in the module's `[modules.\(moduleName).options]` table."
                    : unknownKey("modules.\(moduleName).\(moduleKey)", known: moduleKeys))
            }
            for optionKey in (table(module, "options")?.keys ?? []).sorted() where !optionKeys.contains(optionKey) {
                warnings.append(unknownKey("modules.\(moduleName).options.\(optionKey)", known: optionKeys))
            }
        }
        if modules?.keys.isEmpty != false {
            warnings.append("The Cuckoofile defines no modules: add a `[modules.<Name>]` table for each module to mock.")
        }
        return warnings
    }

    private static let moduleKeys: Set<String> = [
        "imports", "publicImports", "testableImports", "sources", "exclude", "regex", "globalActors", "output",
        "filenameFormat", "options", "xcodeproj",
    ]
    private static let optionKeys: Set<String> = [
        "keepDocumentation", "protocolsOnly", "omitHeaders", "mockPrefix", "mockSuffix",
        "defaultIsolation",
    ]

    private static func unknownKey(_ key: String, known: Set<String>) -> String {
        "The Cuckoofile key '\(key)' isn't one Cuckoo reads, so it's ignored. Known keys here: "
            + known.sorted().joined(separator: ", ") + "."
    }

    enum ParseError: Error, CustomStringConvertible {
        case unreadable(any Error)
        case configurationErrors(details: [String])

        var description: String {
            switch self {
            case .unreadable(let error):
                return """
                Cuckoofile can't be read. Define modules as `[modules.ModuleName]` tables with properties beneath.
                \(error)
                """
            case .configurationErrors(let details):
                return """
                Cuckoofile contains errors:
                \(details.map { "\t- \($0)" }.joined(separator: "\n"))
                """
            }
        }
    }
}
