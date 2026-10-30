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
                sources: sourceModules.flatMap(\.sources)
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
            sources: sourceModules.flatMap(\.sources)
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
    var swiftModule: (name: String, directory: URL)? = nil
}

private func commandsPerModule(
    sourceModules: [SourceModule],
    executableFactory: (String) throws -> PluginContext.Tool,
    projectDir: URL,
    derivedSourcesDir: URL
) throws -> [Command] {
    let configurationURL = projectDir.appending(path: "Cuckoofile.toml")
    let executable = try executableFactory("CuckooGenerator").url

    return sourceModules.map { sourceModule in
        let outputURL = derivedSourcesDir.appending(component: "GeneratedMocks_\(sourceModule.name).swift")

        return .buildCommand(
            displayName: "Run Cuckoonator for \(sourceModule.name)",
            executable: executable,
            arguments: [],
            environment: [
                "PROJECT_DIR": projectDir.path(),
                "DERIVED_SOURCES_DIR": derivedSourcesDir.path(),
                "CUCKOO_OVERRIDE_OUTPUT": outputURL.path(),
                "CUCKOO_MODULE_NAME": sourceModule.name,
                // The generated file imports the sources' types from it by name; see `sources` in the README.
                "CUCKOO_SOURCE_MODULE": sourceModule.swiftModule?.name,
                "CUCKOO_SOURCE_MODULE_DIRECTORY": sourceModule.swiftModule?.directory.path(percentEncoded: false),
            ].compactMapValues { $0 },
            inputFiles: [configurationURL] + sourceModule.sources,
            outputFiles: [outputURL]
        )
    }
}
