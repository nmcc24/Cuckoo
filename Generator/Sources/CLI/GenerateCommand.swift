import Foundation
import ArgumentParser

@main
@available(macOS 12, *)
struct GenerateCommand: AsyncParsableCommand {
    nonisolated(unsafe) static var configuration = CommandConfiguration(
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

    @Flag(help: "Include extra information during generation and in the generated code.")
    var verbose = false

    private var overriddenOutput: String?

    mutating func run() async throws {
        Logger.shared.logLevel = verbose ? .verbose : .info

        let projectDir = ProcessInfo.processInfo.environment["PROJECT_DIR"]
        let configurationFile = [
            configurationPath.map { Path($0) }?.relative(to: projectDir)?.rawValue,
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

        guard let configurationFile else { throw GenerateError.missingConfiguration }

        log(.info, message: "Using configuration file at path:", configurationFile.path)

        overriddenOutput = ProcessInfo.processInfo.environment["CUCKOO_OVERRIDE_OUTPUT"]
        let requestedModuleName = ProcessInfo.processInfo.environment["CUCKOO_MODULE_NAME"]
        let environment = ProcessInfo.processInfo.environment
        let sourceModule = environment["CUCKOO_SOURCE_MODULE"].flatMap { name in
            environment["CUCKOO_SOURCE_MODULE_DIRECTORY"].map { Module.SourceModule(name: name, directory: Path($0)) }
        }

        let pluginSources = try sourcesListPath.map(Self.sourcesList(at:))

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

        // To not capture mutating self.
        let verbose = self.verbose

        await modules.concurrentForEach { module in
            do {
                let outputPath = Path(module.output, expandingTilde: true)
                let absoluteOutputPath: Path
                if outputPath.isAbsolute {
                    absoluteOutputPath = outputPath
                } else {
                    absoluteOutputPath = configurationFile.path.parent + outputPath
                }
                let isOutputDirectory: Bool
                if absoluteOutputPath.exists && absoluteOutputPath.isDirectory {
                    isOutputDirectory = true
                } else {
                    isOutputDirectory = absoluteOutputPath.pathExtension.isEmpty
                    // Create directory structure.
                    if isOutputDirectory {
                        try absoluteOutputPath.createDirectory(withIntermediateDirectories: true)
                    } else {
                        try absoluteOutputPath.parent.createDirectory(withIntermediateDirectories: true)
                    }
                }
                let generatedFiles = try await Generator.generate(
                    for: module,
                    singleFileOutput: !isOutputDirectory,
                    verbose: verbose
                )
                if isOutputDirectory {
                    await generatedFiles.concurrentForEach { generatedFile in
                        let originalFileName = generatedFile.path.fileNameWithoutExtension
                        let fileNameWithoutExtension = module.filenameFormat
                            .map { $0.replacingOccurrences(of: "{}", with: originalFileName) }
                            ?? originalFileName
                        let outputFile = TextFile(path: absoluteOutputPath + "\(fileNameWithoutExtension).swift")
                        do {
                            try outputFile.write(generatedFile.contents)
                        } catch {
                            log(.error, message: "Failed to write to file '\(outputFile)':", error)
                        }
                    }
                } else {
                    let outputFile = TextFile(path: absoluteOutputPath)
                    do {
                        try outputFile.write(generatedFiles.map(\.contents).joined(separator: "\n\n"))
                    } catch {
                        log(.error, message: "Failed to write to file '\(outputFile)':", error)
                    }
                }
            } catch {
                log(.error, message: "Failed to generate mocks for module \(module.name):", error)
            }
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
        return contents
            .split(whereSeparator: \.isNewline)
            .map { line in
                guard let tab = line.firstIndex(of: "\t") else {
                    return Module.PluginSource(path: Path(String(line)).absolute, swiftModule: nil)
                }
                let swiftModule = String(line[..<tab])
                return Module.PluginSource(
                    path: Path(String(line[line.index(after: tab)...])).absolute,
                    swiftModule: swiftModule.isEmpty ? nil : swiftModule
                )
            }
    }

    private enum GenerateError: Error, CustomStringConvertible {
        case missingConfiguration
        case unreadableSourcesList(path: String, any Error)

        var description: String {
            switch self {
            case .missingConfiguration:
                return """
                Failed to find Cuckoofile configuration.
                Expected in project folder through $PROJECT_DIR or in the same directory where the Cuckoonator was called.
                """
            case .unreadableSourcesList(let path, let error):
                return "Failed to read the sources list at '\(path)': \(error)"
            }
        }
    }
}
