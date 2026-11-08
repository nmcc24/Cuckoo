import Foundation
import PackagePlugin

@main
struct CuckooPlugin: BuildToolPlugin {
    func createBuildCommands(context: PluginContext, target: Target) async throws -> [Command] {
        let sourceModules: [SourceModule] = target.dependencies
            .flatMap { dependency in
                switch dependency {
                case .product(let product):
                    return product.targets
                case .target(let target):
                    return [target]
                @unknown default:
                    return []
                }
            }
            .compactMap { $0 as? SourceModuleTarget }
            .filter { $0.kind == ModuleKind.generic && $0.moduleName != "Cuckoo" }
            .map { module in
                SourceModule(
                    name: module.moduleName,
                    sources: module.sourceFiles.filter { $0.type == .source }.map(\.url),
                    swiftModule: (module.moduleName, module.directoryURL)
                )
            }

        // For test targets, also emit a build command keyed by the test target's own name.
        // This allows Cuckoofile.toml to have a [modules.TestTargetName] entry that mocks
        // specific files from any dependency, independently of per-dependency mock generation.
        var allSourceModules = sourceModules
        if let testTarget = target as? SourceModuleTarget, testTarget.kind == .test {
            let selfModule = SourceModule(
                name: target.name,
                sources: sourceModules.flatMap(\.sources),
                listedSources: sourceModules.flatMap(\.listedSources)
            )
            allSourceModules.append(selfModule)
        }

        return try commandsPerModule(
            sourceModules: allSourceModules,
            executableFactory: context.tool(named:),
            targetName: target.name,
            projectDir: context.package.directoryURL,
            derivedSourcesDir: context.pluginWorkDirectoryURL
        )
    }
}

#if canImport(XcodeProjectPlugin)
import XcodeProjectPlugin

extension CuckooPlugin: XcodeBuildToolPlugin {
    func createBuildCommands(context: XcodePluginContext, target: XcodeTarget) throws -> [Command] {
        let sourceModules: [SourceModule] = target.dependencies
            .flatMap { dependency in
                switch dependency {
                case .product(let product):
                    return product.targets
                        .compactMap { $0 as? SwiftSourceModuleTarget }
                        .filter { $0.kind == ModuleKind.generic && $0.moduleName != "Cuckoo" }
                        .map { module in
                            SourceModule(
                                name: module.moduleName,
                                sources: module.sourceFiles.filter { $0.type == .source }.map(\.url),
                                swiftModule: (module.moduleName, module.directoryURL)
                            )
                        }
                case .target(let target):
                    guard target.displayName != "Cuckoo" else { return [] }
                    return [SourceModule(
                        name: target.displayName,
                        sources: target.inputFiles.filter { $0.type == .source }.map(\.url)
                    )]
                @unknown default:
                    return []
                }
            }

        // For test targets, also emit a build command keyed by the test target's own name.
        // This allows Cuckoofile.toml to have a [modules.TestTargetName] entry that mocks
        // specific files from any dependency, independently of per-dependency mock generation.
        var allSourceModules = sourceModules
        let selfModule = SourceModule(
            name: target.displayName,
            sources: sourceModules.flatMap(\.sources),
            listedSources: sourceModules.flatMap(\.listedSources)
        )
        allSourceModules.append(selfModule)

        return try commandsPerModule(
            sourceModules: allSourceModules,
            executableFactory: context.tool(named:),
            targetName: target.displayName,
            projectDir: context.xcodeProject.directoryURL,
            derivedSourcesDir: context.pluginWorkDirectoryURL
        )
    }
}
#endif

struct SourceModule {
    let name: String
    let sources: [URL]
    /// The Swift module the sources are compiled into, and its directory, where it's certain: not for a test
    /// target's own entry, which gathers the sources of all its dependencies, nor for an Xcode target, whose
    /// display name may differ. The Cuckoofile entry may list files from elsewhere, which belong to other modules.
    let swiftModule: (name: String, directory: URL)?
    /// The sources passed to the generator, each with its Swift module where it's certain.
    let listedSources: [ListedSource]

    init(name: String, sources: [URL], swiftModule: (name: String, directory: URL)? = nil, listedSources: [ListedSource]? = nil) {
        self.name = name
        self.sources = sources
        self.swiftModule = swiftModule
        self.listedSources = listedSources ?? sources.map { ListedSource(swiftModule: swiftModule?.name, url: $0) }
    }
}

private func commandsPerModule(
    sourceModules: [SourceModule],
    executableFactory: (String) throws -> PluginContext.Tool,
    targetName: String,
    projectDir: URL,
    derivedSourcesDir: URL
) throws -> [Command] {
    let configurationURL = projectDir.appending(path: "Cuckoofile.toml")
    let executable = try executableFactory("CuckooGenerator").url

    return try sourceModules.map { sourceModule in
        let outputURL = derivedSourcesDir.appending(component: "GeneratedMocks_\(sourceModule.name).swift")
        // The Cuckoofile module mocks these files unless it lists its own `sources`.
        let sourcesListURL = derivedSourcesDir.appending(component: "Sources_\(sourceModule.name).txt")
        let listing = try sourcesArguments(sourceModule.listedSources, listURL: sourcesListURL)

        return .buildCommand(
            // SwiftPM names a command by its display name and arguments, so two test targets that depend on the same
            // module would get one command between them without the target's name here.
            displayName: "Run Cuckoonator for \(sourceModule.name) in \(targetName)",
            executable: executable,
            arguments: listing.arguments,
            environment: [
                "PROJECT_DIR": projectDir.path(percentEncoded: false),
                "DERIVED_SOURCES_DIR": derivedSourcesDir.path(percentEncoded: false),
                "CUCKOO_OVERRIDE_OUTPUT": outputURL.path(percentEncoded: false),
                "CUCKOO_MODULE_NAME": sourceModule.name,
                // A generator built from source with code coverage (an Xcode scheme gathering it) writes its profile
                // here: the sandbox lets it write only in the plugin's work directory.
                "LLVM_PROFILE_FILE": derivedSourcesDir.appending(component: "CuckooGenerator-%m.profraw").path(percentEncoded: false),
                // The generated file imports the sources' types from it by name; see `sources` in Source/Cuckoo.docc/Cuckoofile.md.
                "CUCKOO_SOURCE_MODULE": sourceModule.swiftModule?.name,
                "CUCKOO_SOURCE_MODULE_DIRECTORY": sourceModule.swiftModule?.directory.path(percentEncoded: false),
            ].compactMapValues { $0 },
            inputFiles: [configurationURL] + listing.inputFiles + sourceModule.sources,
            outputFiles: [outputURL]
        )
    }
}

/// A file for the generator's source listing, and the Swift module it belongs to where that's certain.
struct ListedSource {
    let swiftModule: String?
    let url: URL
}

/// The generator's arguments for a target's files: one `--source` per file, so the command needs no file of its own
/// and a deleted plugin directory regenerates on the next build. A long listing, which could pass the system's limit
/// on command-line length, goes in a `--sources-list` file instead, as does an empty one, which `--source` can't express.
private func sourcesArguments(_ sources: [ListedSource], listURL: URL) throws -> (arguments: [String], inputFiles: [URL]) {
    let lines = sources.map { "\($0.swiftModule ?? "")\t\($0.url.path(percentEncoded: false))" }
    if !lines.isEmpty && lines.reduce(0, { $0 + $1.utf8.count + 10 }) <= maximumInlineSourcesLength {
        return (lines.flatMap { ["--source", $0] }, [])
    }
    try writeSourcesList(lines, to: listURL)
    return (["--sources-list", listURL.path(percentEncoded: false)], [listURL])
}

/// Well under macOS's 1 MiB limit on a command's arguments and environment together.
private let maximumInlineSourcesLength = 256 * 1024

/// Writes the source files for the generator's `--sources-list`, one per line: the Swift module, a tab and the path.
/// An unchanged list isn't rewritten, so the build only reruns the generator when the target's files change.
private func writeSourcesList(_ lines: [String], to url: URL) throws {
    let contents = Data(lines.map { "\($0)\n" }.joined().utf8)
    guard (try? Data(contentsOf: url)) != contents else { return }
    try FileManager.default.createDirectory(at: url.deletingLastPathComponent(), withIntermediateDirectories: true)
    try contents.write(to: url, options: .atomic)
}
