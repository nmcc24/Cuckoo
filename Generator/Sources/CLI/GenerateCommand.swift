#if canImport(FoundationEssentials)
import FoundationEssentials
#else
import Foundation
#endif
import ArgumentParser

@main
struct GenerateCommand: AsyncParsableCommand {
    static let configuration = CommandConfiguration(
        commandName: "CuckooGenerator",
        abstract: "Generates Cuckoo mocks for the modules of a Cuckoofile.",
        version: version,
        helpNames: .shortAndLong
    )

    @Option(
        name: [.customLong("configuration")],
        help: "The Cuckoofile to read. By default, Cuckoofile.toml in $PROJECT_DIR, then in the current directory.",
        completion: .file()
    )
    var configurationPath: String?

    @Option(
        name: [.customLong("sources-list")],
        help: """
            A file listing source files, one per line, for the modules that don't set `sources`: a path, or the \
            Swift module the file belongs to, a tab and the path. The build plugins pass the files of the targets \
            they generate for.
            """,
        completion: .file()
    )
    var sourcesListPath: String?

    @Option(
        name: [.customLong("source")],
        help: """
            A source file for the modules that don't set `sources`, in the form of a `--sources-list` line. Repeat it \
            for each file. The build plugins pass a target's files this way unless the list is long.
            """
    )
    var sourceEntries: [String] = []

    @Flag(help: "Include extra information during generation and in the generated code.")
    var verbose = false

    func run() async throws {
        try await run(environment: ProcessInfo.processInfo.environment)
    }

    /// Generates with `environment` as the process's: the build plugins pass `PROJECT_DIR`, `CUCKOO_OVERRIDE_OUTPUT`,
    /// `CUCKOO_MODULE_NAME` and `CUCKOO_SOURCE_MODULE`(`_DIRECTORY`) this way.
    func run(environment: [String: String]) async throws {
        try await Logger.$level.withValue(verbose ? .verbose : .info) {
            try await generate(environment: environment)
        }
    }

    private func generate(environment: [String: String]) async throws {
        let projectDir = environment["PROJECT_DIR"]
        let configurationFile: (path: Path, contents: String)?
        if let configurationPath {
            // A relative path resolves against the project directory when there is one, else the current directory.
            let path = Path(configurationPath, expandingTilde: true)
                .relative(to: projectDir ?? FileManager.default.currentDirectoryPath)
            do {
                configurationFile = (path, try String(contentsOfFile: path.rawValue, encoding: .utf8))
            } catch {
                throw GenerateError.unreadableConfiguration(path: path.rawValue, error)
            }
        } else {
            configurationFile = [
                projectDir.map { URL(filePath: $0, directoryHint: .isDirectory).appending(path: "Cuckoofile.toml").path(percentEncoded: false) },
                URL(filePath: FileManager.default.currentDirectoryPath, directoryHint: .isDirectory)
                    .appending(path: "Cuckoofile.toml").path(percentEncoded: false),
            ]
            .lazy
            .compactMap { pathString -> (path: Path, contents: String)? in
                guard let pathString else { return nil }
                let path = Path(pathString, expandingTilde: true)
                guard let contents = try? String(contentsOfFile: path.rawValue, encoding: .utf8) else { return nil }
                return (path: path, contents: contents)
            }
            .first
        }

        guard let configurationFile else { throw GenerateError.missingConfiguration }

        log(.info, message: "Using configuration file at path:", configurationFile.path)

        let overriddenOutput = environment["CUCKOO_OVERRIDE_OUTPUT"]
        let requestedModuleName = environment["CUCKOO_MODULE_NAME"]
        let sourceModule = environment["CUCKOO_SOURCE_MODULE"].flatMap { name in
            environment["CUCKOO_SOURCE_MODULE_DIRECTORY"].map { Module.SourceModule(name: name, directory: Path($0)) }
        }

        // The plugins pass a target's files as `--source` arguments, or as a `--sources-list` file when there are many.
        let pluginSources: [Module.PluginSource]? = if sourcesListPath == nil && sourceEntries.isEmpty {
            nil
        } else {
            try (sourcesListPath.map(Self.sourcesList(at:)) ?? []) + sourceEntries.map(Self.pluginSource(fromLine:))
        }

        for warning in Cuckoofile.warnings(for: configurationFile.contents, module: requestedModuleName) {
            printToStandardError("warning: cuckoo: \(configurationFile.path): \(warning)\n")
        }
        let modules = try Cuckoofile.modules(
            from: configurationFile.contents,
            configurationPath: configurationFile.path,
            overriddenOutput: overriddenOutput,
            requestedModuleName: requestedModuleName,
            sourceModule: sourceModule,
            pluginSources: pluginSources
        )

        if modules.isEmpty {
            if let requestedModuleName {
                log(.info, message: "No module named '\(requestedModuleName)' found in Cuckoofile, skipping generation.")
            }
            if let outputPath = overriddenOutput {
                let path = Path(outputPath, expandingTilde: true)
                try? path.parent.createDirectory(withIntermediateDirectories: true)
                try? TextFile(path: path).write("")
            }
            return
        }

        // Modules that write to the same file are joined into it.
        var fileOutputs: [(path: Path, modules: [Module])] = []
        var directoryOutputs: [(path: Path, module: Module)] = []
        for module in modules {
            let outputPath = Path(module.output, expandingTilde: true)
            let absoluteOutputPath = outputPath.isAbsolute ? outputPath : configurationFile.path.parent + outputPath
            // An existing directory, or a path without an extension, is a directory of one file per source.
            if absoluteOutputPath.isDirectory || absoluteOutputPath.pathExtension.isEmpty {
                directoryOutputs.append((absoluteOutputPath, module))
            } else if let index = fileOutputs.firstIndex(where: { $0.path.standardRawValue == absoluteOutputPath.standardRawValue }) {
                fileOutputs[index].modules.append(module)
            } else {
                fileOutputs.append((absoluteOutputPath, [module]))
            }
        }

        // A failure doesn't stop the other outputs, but it fails the run, so a build doesn't go on with stale mocks.
        let generated = await directoryOutputs.concurrentMap { output -> Result<[(path: Path, contents: String, module: String)], DirectoryOutputError> in
            let module = output.module
            do {
                try output.path.createDirectory(withIntermediateDirectories: true)
                let generatedFiles = try await Generator.generate(for: module, singleFileOutput: false, verbose: verbose)
                let names = Self.outputNames(for: generatedFiles.map(\.path))
                return .success(zip(generatedFiles, names).map { generatedFile, originalFileName in
                    let fileNameWithoutExtension = module.filenameFormat
                        .map { $0.replacing("{}", with: originalFileName) }
                        ?? originalFileName
                    return (output.path + "\(fileNameWithoutExtension).swift", generatedFile.contents, module.name)
                })
            } catch {
                return .failure(DirectoryOutputError(message: "Failed to generate mocks for module \(module.name): \(error)"))
            }
        }
        var directoryFailures = generated.compactMap { result -> String? in
            if case .failure(let error) = result { return error.message }
            return nil
        }
        // Two modules writing the same file in a shared directory would overwrite each other, so neither writes it and
        // the run fails. Paths are compared ignoring case, as the default file systems on macOS and Windows do.
        let files = generated.flatMap { (try? $0.get()) ?? [] }
        let clashes = Dictionary(grouping: files, by: { $0.path.standardRawValue.lowercased() })
            .filter { Set($0.value.map(\.module)).count > 1 }
        directoryFailures += clashes.values.map { clash in
            let modules = Set(clash.map(\.module)).sorted().joined(separator: " and ")
            return "Modules \(modules) would both write '\(clash[0].path)': give them different output directories, or a filenameFormat."
        }.sorted()
        directoryFailures += await files.filter { clashes[$0.path.standardRawValue.lowercased()] == nil }
            .concurrentCompactMap { file -> String? in
                let outputFile = TextFile(path: file.path)
                do {
                    try outputFile.write(file.contents)
                    return nil
                } catch {
                    return "Failed to write to file '\(outputFile)': \(error)"
                }
            }

        let fileFailures = await fileOutputs.concurrentCompactMap { output -> String? in
            let names = output.modules.map(\.name).joined(separator: ", ")
            do {
                try output.path.parent.createDirectory(withIntermediateDirectories: true)
                let contents = if let module = output.modules.first, output.modules.count == 1 {
                    try await Generator.generate(for: module, singleFileOutput: true, verbose: verbose)
                        .map(\.contents)
                        .joinedByBlankLines()
                } else {
                    try await Generator.generateJoined(for: output.modules, verbose: verbose)
                }
                let outputFile = TextFile(path: output.path)
                do {
                    try outputFile.write(contents)
                } catch {
                    return "Failed to write to file '\(outputFile)': \(error)"
                }
                return nil
            } catch {
                return "Failed to generate mocks for module \(names): \(error)"
            }
        }

        let failures = directoryFailures + fileFailures
        guard failures.isEmpty else {
            for failure in failures {
                printToStandardError("error: \(failure)\n")
            }
            throw ExitCode.failure
        }
    }

    /// The name of each source file's mocks in a directory output: the file's name, or, for files that share one,
    /// enough of their parent directories, joined by `_`, to tell them apart (`A/User.swift` and `B/User.swift`
    /// give `A_User` and `B_User`).
    static func outputNames(for sources: [Path]) -> [String] {
        // Names differing only in case are one file on macOS's default file system.
        let groups = Dictionary(grouping: sources.indices) { sources[$0].fileNameWithoutExtension.lowercased() }
        var names = sources.map(\.fileNameWithoutExtension)
        for indices in groups.values where indices.count > 1 {
            let directories = indices.map { sources[$0].parent.components.map(\.fileName).filter { $0 != "/" } }
            let longest = directories.map(\.count).max() ?? 0
            // The fewest parent directories that make the group's names unique; all of them when even that doesn't.
            let depth = (1...max(longest, 1)).first { depth in
                Set(directories.map { $0.suffix(depth).joined(separator: "/").lowercased() }).count == indices.count
            } ?? longest
            for (index, directory) in zip(indices, directories) {
                names[index] = (directory.suffix(depth) + [names[index]]).joined(separator: "_")
            }
        }
        return names
    }

    /// The files in a `--sources-list` file, one per line: a path, or a Swift module, a tab and a path. A relative
    /// path resolves against the current directory.
    static func sourcesList(at path: String) throws -> [Module.PluginSource] {
        let contents: String
        do {
            contents = try String(contentsOfFile: Path(path, expandingTilde: true).rawValue, encoding: .utf8)
        } catch {
            throw GenerateError.unreadableSourcesList(path: path, error)
        }
        return contents.split(whereSeparator: \.isNewline).map(pluginSource(fromLine:))
    }

    /// One `--sources-list` line or `--source` value: a path, or a Swift module, a tab and a path.
    static func pluginSource(fromLine line: some StringProtocol) -> Module.PluginSource {
        guard let tab = line.firstIndex(of: "\t") else {
            return Module.PluginSource(path: Path(String(line)).absolute, swiftModule: nil)
        }
        let swiftModule = String(line[..<tab])
        return Module.PluginSource(
            path: Path(String(line[line.index(after: tab)...])).absolute,
            swiftModule: swiftModule.isEmpty ? nil : swiftModule
        )
    }

    private enum GenerateError: Error, CustomStringConvertible {
        case missingConfiguration
        case unreadableSourcesList(path: String, any Error)
        case unreadableConfiguration(path: String, any Error)

        var description: String {
            switch self {
            case .missingConfiguration:
                return """
                No Cuckoofile.toml found. The generator looks in $PROJECT_DIR, which the build plugin sets to the package's or \
                Xcode project's folder, and then in the current directory. Pass --configuration to name another file.
                """
            case .unreadableSourcesList(let path, let error):
                return "Failed to read the sources list at '\(path)': \(error)"
            case .unreadableConfiguration(let path, let error):
                return "Failed to read the Cuckoofile at '\(path)': \(error)"
            }
        }
    }

    private struct DirectoryOutputError: Error {
        let message: String
    }
}
