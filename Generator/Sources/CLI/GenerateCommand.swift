#if canImport(FoundationEssentials)
import FoundationEssentials
#else
import Foundation
#endif
import ArgumentParser

@main
struct GenerateCommand: AsyncParsableCommand {
    static let configuration = CommandConfiguration(
        commandName: "Generate",
        abstract: "Cuckoo CLI tool for generating mocks according to the specified configuration.",
        version: version,
        helpNames: .shortAndLong
    )

    @Option(
        name: [.customLong("configuration")],
        help: "Set Cuckoofile path. By default the Cuckoonator looks for it in the project root.",
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
        try await Logger.$level.withValue(verbose ? .verbose : .info) {
            try await generate()
        }
    }

    private func generate() async throws {

        let projectDir = ProcessInfo.processInfo.environment["PROJECT_DIR"]
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
                projectDir.map { "\($0)/Cuckoofile.toml" },
                "\(FileManager.default.currentDirectoryPath)/Cuckoofile.toml",
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

        let overriddenOutput = ProcessInfo.processInfo.environment["CUCKOO_OVERRIDE_OUTPUT"]
        let requestedModuleName = ProcessInfo.processInfo.environment["CUCKOO_MODULE_NAME"]
        let environment = ProcessInfo.processInfo.environment
        let sourceModule = environment["CUCKOO_SOURCE_MODULE"].flatMap { name in
            environment["CUCKOO_SOURCE_MODULE_DIRECTORY"].map { Module.SourceModule(name: name, directory: Path($0)) }
        }

        // The plugins pass a target's files as `--source` arguments, or as a `--sources-list` file when there are many.
        let pluginSources: [Module.PluginSource]? = if sourcesListPath == nil && sourceEntries.isEmpty {
            nil
        } else {
            try (sourcesListPath.map(Self.sourcesList(at:)) ?? []) + sourceEntries.map(Self.pluginSource(fromLine:))
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
        let directoryFailures = await directoryOutputs.concurrentMap { output -> [String] in
            let module = output.module
            do {
                try output.path.createDirectory(withIntermediateDirectories: true)
                let generatedFiles = try await Generator.generate(for: module, singleFileOutput: false, verbose: verbose)
                return await generatedFiles.concurrentCompactMap { generatedFile -> String? in
                    let originalFileName = generatedFile.path.fileNameWithoutExtension
                    let fileNameWithoutExtension = module.filenameFormat
                        .map { $0.replacing("{}", with: originalFileName) }
                        ?? originalFileName
                    let outputFile = TextFile(path: output.path + "\(fileNameWithoutExtension).swift")
                    do {
                        try outputFile.write(generatedFile.contents)
                        return nil
                    } catch {
                        return "Failed to write to file '\(outputFile)': \(error)"
                    }
                }
            } catch {
                return ["Failed to generate mocks for module \(module.name): \(error)"]
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

        let failures = directoryFailures.flatMap(\.self) + fileFailures
        guard failures.isEmpty else {
            for failure in failures {
                printToStandardError("error: \(failure)\n")
            }
            throw ExitCode.failure
        }
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
                Failed to find Cuckoofile configuration.
                Expected in project folder through $PROJECT_DIR or in the same directory where the Cuckoonator was called.
                """
            case .unreadableSourcesList(let path, let error):
                return "Failed to read the sources list at '\(path)': \(error)"
            case .unreadableConfiguration(let path, let error):
                return "Failed to read the Cuckoofile at '\(path)': \(error)"
            }
        }
    }
}
