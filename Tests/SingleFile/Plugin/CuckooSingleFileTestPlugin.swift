import Foundation
import PackagePlugin

/// Generates every Cuckoofile module into one file for `CuckooSingleFileMocks`, as the generator does for modules that
/// share an `output`, so the runtime tests compile the merged imports. Only this package's tests use it.
@main
struct CuckooSingleFileTestPlugin: BuildToolPlugin {
    func createBuildCommands(context: PluginContext, target: Target) async throws -> [Command] {
        let sources: [ListedSource] = target.dependencies
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
            .flatMap { module in
                module.sourceFiles.filter { $0.type == .source }.map { ListedSource(swiftModule: module.moduleName, url: $0.url) }
            }

        return try commands(
            sources: sources,
            executableFactory: context.tool(named:),
            projectDir: context.package.directoryURL,
            derivedSourcesDir: context.pluginWorkDirectoryURL
        )
    }
}

func commands(
    sources: [ListedSource],
    executableFactory: (String) throws -> PluginContext.Tool,
    projectDir: URL,
    derivedSourcesDir: URL
) throws -> [Command] {
    let configurationURL = projectDir.appending(path: "Cuckoofile.toml")
    let outputURL = derivedSourcesDir.appending(component: "GeneratedMocks.swift")
    // A Cuckoofile module that doesn't list its own `sources` mocks the files of the dependency with its name, or all
    // of them if no dependency has its name.
    let sourcesListURL = derivedSourcesDir.appending(component: "Sources.txt")
    let listing = try sourcesArguments(sources, listURL: sourcesListURL)

    return [
        .buildCommand(
            displayName: "Run Cuckoonator (single file)",
            executable: try executableFactory("CuckooGenerator").url,
            arguments: listing.arguments,
            environment: [
                "PROJECT_DIR": projectDir.path(percentEncoded: false),
                "DERIVED_SOURCES_DIR": derivedSourcesDir.path(percentEncoded: false),
                "CUCKOO_OVERRIDE_OUTPUT": outputURL.path(percentEncoded: false),
                // A generator built from source with code coverage (an Xcode scheme gathering it) writes its profile
                // here: the sandbox lets it write only in the plugin's work directory.
                "LLVM_PROFILE_FILE": derivedSourcesDir.appending(component: "CuckooGenerator-%m.profraw").path(percentEncoded: false),
            ],
            inputFiles: [configurationURL] + listing.inputFiles + sources.map(\.url),
            outputFiles: [outputURL]
        )
    ]
}
