import Foundation
import PackagePlugin

@main
struct CuckooPluginFile: BuildToolPlugin {
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

#if canImport(XcodeProjectPlugin)
import XcodeProjectPlugin

extension CuckooPluginFile: XcodeBuildToolPlugin {
    func createBuildCommands(context: XcodePluginContext, target: XcodeTarget) throws -> [Command] {
        let sources: [ListedSource] = target.dependencies
            .flatMap { dependency in
                switch dependency {
                case .product(let product):
                    return product.targets
                        .compactMap { $0 as? SwiftSourceModuleTarget }
                        .filter { $0.kind == ModuleKind.generic && $0.moduleName != "Cuckoo" }
                        .flatMap { module in
                            module.sourceFiles.filter { $0.type == .source }.map { ListedSource(swiftModule: module.moduleName, url: $0.url) }
                        }
                case .target(let target):
                    // An Xcode target's display name may differ from its Swift module's name.
                    guard target.displayName != "Cuckoo" else { return [] }
                    return target.inputFiles.filter { $0.type == .source }.map { ListedSource(swiftModule: nil, url: $0.url) }
                @unknown default:
                    return []
                }
            }

        return try commands(
            sources: sources,
            executableFactory: context.tool(named:),
            projectDir: context.xcodeProject.directoryURL,
            derivedSourcesDir: context.pluginWorkDirectoryURL
        )
    }
}
#endif

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
    try writeSourcesList(sources, to: sourcesListURL)

    return [
        .buildCommand(
            displayName: "Run Cuckoonator (single file)",
            executable: try executableFactory("CuckooGenerator").url,
            arguments: ["--sources-list", sourcesListURL.path(percentEncoded: false)],
            environment: [
                "PROJECT_DIR": projectDir.path(percentEncoded: false),
                "DERIVED_SOURCES_DIR": derivedSourcesDir.path(percentEncoded: false),
                "CUCKOO_OVERRIDE_OUTPUT": outputURL.path(percentEncoded: false),
            ],
            inputFiles: [configurationURL, sourcesListURL] + sources.map(\.url),
            outputFiles: [outputURL]
        )
    ]
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
