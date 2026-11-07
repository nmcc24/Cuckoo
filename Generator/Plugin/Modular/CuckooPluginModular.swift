import Foundation
import PackagePlugin

@main
struct CuckooPluginModular: BuildToolPlugin {
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
            projectDir: context.package.directoryURL,
            derivedSourcesDir: context.pluginWorkDirectoryURL
        )
    }
}

#if canImport(XcodeProjectPlugin)
import XcodeProjectPlugin

extension CuckooPluginModular: XcodeBuildToolPlugin {
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
    /// The sources passed with `--sources-list`, each with its Swift module where it's certain.
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
    projectDir: URL,
    derivedSourcesDir: URL
) throws -> [Command] {
    let configurationURL = projectDir.appending(path: "Cuckoofile.toml")
    let executable = try executableFactory("CuckooGenerator").url

    return try sourceModules.map { sourceModule in
        let outputURL = derivedSourcesDir.appending(component: "GeneratedMocks_\(sourceModule.name).swift")
        // The Cuckoofile module mocks these files unless it lists its own `sources`.
        let sourcesListURL = derivedSourcesDir.appending(component: "Sources_\(sourceModule.name).txt")
        try writeSourcesList(sourceModule.listedSources, to: sourcesListURL)

        return .buildCommand(
            displayName: "Run Cuckoonator for \(sourceModule.name)",
            executable: executable,
            arguments: ["--sources-list", sourcesListURL.path(percentEncoded: false)],
            environment: [
                "PROJECT_DIR": projectDir.path(percentEncoded: false),
                "DERIVED_SOURCES_DIR": derivedSourcesDir.path(percentEncoded: false),
                "CUCKOO_OVERRIDE_OUTPUT": outputURL.path(percentEncoded: false),
                "CUCKOO_MODULE_NAME": sourceModule.name,
                // The generated file imports the sources' types from it by name; see `sources` in Source/Cuckoo.docc/Cuckoofile.md.
                "CUCKOO_SOURCE_MODULE": sourceModule.swiftModule?.name,
                "CUCKOO_SOURCE_MODULE_DIRECTORY": sourceModule.swiftModule?.directory.path(percentEncoded: false),
            ].compactMapValues { $0 },
            inputFiles: [configurationURL, sourcesListURL] + sourceModule.sources,
            outputFiles: [outputURL]
        )
    }
}

/// A file for the generator's `--sources-list`, and the Swift module it belongs to where that's certain.
struct ListedSource {
    let swiftModule: String?
    let url: URL
}

/// Writes the source files for the generator's `--sources-list`, one per line: the Swift module, a tab and the path.
/// An unchanged list isn't rewritten, so the build only reruns the generator when the target's files change.
private func writeSourcesList(_ sources: [ListedSource], to url: URL) throws {
    let contents = Data(sources.map { "\($0.swiftModule ?? "")\t\($0.url.path(percentEncoded: false))\n" }.joined().utf8)
    guard (try? Data(contentsOf: url)) != contents else { return }
    try FileManager.default.createDirectory(at: url.deletingLastPathComponent(), withIntermediateDirectories: true)
    try contents.write(to: url, options: .atomic)
}
