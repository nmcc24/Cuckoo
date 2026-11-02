import Foundation
import PackagePlugin

@main
struct CuckooPluginFile: BuildToolPlugin {
    func createBuildCommands(context: PluginContext, target: Target) async throws -> [Command] {
        let sources: [FileList.Element] = target.dependencies
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
            .flatMap(\.sourceFiles)
            .filter { $0.type == .source }

        return try commands(
            sources: sources.map(\.url),
            executableFactory: context.tool(named:),
            projectDir: context.package.directoryURL,
            derivedSourcesDir: context.pluginWorkDirectoryURL
        )
    }
}

#if canImport(XcodeProjectPlugin)
import XcodeProjectPlugin

extension CuckooPluginFile: XcodeBuildToolPlugin {
    func createBuildCommands(context: XcodePluginContext, target: XcodeTarget) throws -> [Command] {
        let sources: [FileList.Element] = target.dependencies
            .flatMap { dependency in
                switch dependency {
                case .product(let product):
                    return product.targets
                        .compactMap { $0 as? SwiftSourceModuleTarget }
                        .filter { $0.kind == ModuleKind.generic && $0.moduleName != "Cuckoo" }
                        .flatMap(\.sourceFiles)
                        .filter { $0.type == .source }
                case .target(let target):
                    guard target.displayName != "Cuckoo" else { return [] }
                    return target.inputFiles.filter { $0.type == .source }
                @unknown default:
                    return []
                }
            }

        return try commands(
            sources: sources.map(\.url),
            executableFactory: context.tool(named:),
            projectDir: context.xcodeProject.directoryURL,
            derivedSourcesDir: context.pluginWorkDirectoryURL
        )
    }
}
#endif

func commands(
    sources: [URL],
    executableFactory: (String) throws -> PluginContext.Tool,
    projectDir: URL,
    derivedSourcesDir: URL
) throws -> [Command] {
    let configurationURL = projectDir.appending(path: "Cuckoofile.toml")
    let outputURL = derivedSourcesDir.appending(component: "GeneratedMocks.swift")
    // The Cuckoofile modules that don't list their own `sources` mock these files.
    let sourcesListURL = derivedSourcesDir.appending(component: "Sources.txt")
    try writeSourcesList(sources, to: sourcesListURL)

    return [
        .buildCommand(
            displayName: "Run Cuckoonator (single file)",
            executable: try executableFactory("CuckooGenerator").url,
            arguments: ["--sources-list", sourcesListURL.path(percentEncoded: false)],
            environment: [
                "PROJECT_DIR": projectDir.path(),
                "DERIVED_SOURCES_DIR": derivedSourcesDir.path(),
                "CUCKOO_OVERRIDE_OUTPUT": outputURL.path(),
            ],
            inputFiles: [configurationURL, sourcesListURL] + sources,
            outputFiles: [outputURL]
        )
    ]
}

/// Writes the source files, one path per line, for the generator's `--sources-list`. An unchanged list isn't
/// rewritten, so the build only reruns the generator when the target's files change.
private func writeSourcesList(_ sources: [URL], to url: URL) throws {
    let contents = Data(sources.map { $0.path(percentEncoded: false) + "\n" }.joined().utf8)
    guard (try? Data(contentsOf: url)) != contents else { return }
    try FileManager.default.createDirectory(at: url.deletingLastPathComponent(), withIntermediateDirectories: true)
    try contents.write(to: url, options: .atomic)
}
