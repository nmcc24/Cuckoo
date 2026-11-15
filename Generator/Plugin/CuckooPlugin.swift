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
            .filter { isMockable($0.kind) && $0.moduleName != "Cuckoo" }
            .map { module in
                SourceModule(
                    name: module.moduleName,
                    sources: module.sourceFiles.filter { $0.type == .source }.map(\.url),
                    swiftModule: (module.moduleName, module.directoryURL)
                )
            }

        // Also a build command keyed by the target's own name, as in an Xcode project, so the Cuckoofile can have a
        // `[modules.TargetName]` entry that mocks files of any dependency, or lists its own `sources`.
        let selfModule = SourceModule(
            name: target.name,
            sources: sourceModules.flatMap(\.sources),
            listedSources: sourceModules.flatMap(\.listedSources)
        )
        let configuration = try readCuckoofile(in: context.package.directoryURL)
        // An entry for none of them generates nothing, without an error: usually a misspelled or renamed module.
        let entries = cuckoofileModuleNames(in: configuration)
        let generated = Set(sourceModules.map(\.name) + [target.name])
        if !entries.isEmpty, entries.isDisjoint(with: generated) {
            Diagnostics.warning(
                "The Cuckoofile has no entry for target '\(target.name)' or its dependencies (\(generated.sorted().joined(separator: ", "))), "
                    + "so it gets no mocks. Its entries: \(entries.sorted().joined(separator: ", ")). Name an entry after one of them."
            )
        }

        return try commandsPerModule(
            sourceModules: sourceModules + [selfModule],
            executableFactory: context.tool(named:),
            targetName: target.name,
            projectDir: context.package.directoryURL,
            configuration: configuration,
            derivedSourcesDir: context.pluginWorkDirectoryURL,
            projectSources: context.package.targets
                .compactMap { $0 as? SourceModuleTarget }
                .flatMap { $0.sourceFiles.filter { $0.type == .source }.map(\.url) }
        )
    }
}

#if canImport(XcodeProjectPlugin)
import XcodeProjectPlugin

extension CuckooPlugin: XcodeBuildToolPlugin {
    func createBuildCommands(context: XcodePluginContext, target: XcodeTarget) throws -> [Command] {
        let projectDir = context.xcodeProject.directoryURL
        let configuration = try readCuckoofile(in: projectDir)

        // Xcode reports a test target's dependencies on packages' products, but not on targets of its own
        // project. An entry for those is named after the test target and lists its `sources`, as in Cuckoo 2.
        let sourceModules: [SourceModule] = target.dependencies.flatMap { dependency -> [SourceModule] in
            switch dependency {
            case .product(let product):
                return product.targets
                    .compactMap { $0 as? SwiftSourceModuleTarget }
                    .filter { isMockable($0.kind) && $0.moduleName != "Cuckoo" }
                    .map { module in
                        SourceModule(
                            name: module.moduleName,
                            sources: module.sourceFiles.filter { $0.type == .source }.map(\.url),
                            swiftModule: (module.moduleName, module.directoryURL)
                        )
                    }
            case .target(let target):
                guard target.displayName != "Cuckoo" else { return [] }
                return [SourceModule(name: target.displayName, sources: target.inputFiles.filter { $0.type == .source }.map(\.url))]
            @unknown default:
                return []
            }
        }
        // Without an entry this target generates, or with one that lists no files, it would compile no mocks and
        // say nothing. The line reader can misread an unusual Cuckoofile, so one that mentions `modules` but where
        // it finds no entry at all isn't an error here; an empty one, or one without `modules`, is.
        let entries = cuckoofileModuleNames(in: configuration)
        let generated = Set(sourceModules.map(\.name) + [target.displayName])
        let readerMayHaveMissedEntries = entries.isEmpty && configuration.contains("modules")
        if !readerMayHaveMissedEntries, entries.isDisjoint(with: generated) {
            throw XcodeTestTargetWithoutEntryError(testTarget: target.displayName, entries: entries.sorted(), listsNoSources: false)
        }
        if sourceModules.isEmpty, entries.contains(target.displayName),
           !cuckoofileEntry(named: target.displayName, listsSourcesIn: configuration) {
            throw XcodeTestTargetWithoutEntryError(testTarget: target.displayName, entries: entries.sorted(), listsNoSources: true)
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
            projectDir: projectDir,
            configuration: configuration,
            derivedSourcesDir: context.pluginWorkDirectoryURL,
            projectSources: context.xcodeProject.targets.flatMap { $0.inputFiles.filter { $0.type == .source }.map(\.url) }
        )
    }
}
/// An Xcode test target uses the plugin, but the Cuckoofile has no entry it generates.
struct XcodeTestTargetWithoutEntryError: Error, CustomStringConvertible {
    let testTarget: String
    let entries: [String]
    /// The test target's entry exists but lists no `sources`.
    let listsNoSources: Bool

    var description: String {
        let key = testTarget.allSatisfy { $0.isLetter || $0.isNumber || $0 == "_" || $0 == "-" } ? testTarget : "\"\(testTarget)\""
        let problem = listsNoSources
            ? "The Cuckoofile entry [modules.\(key)] lists no sources, so it mocks nothing."
            : "The Cuckoofile has no entry for the Xcode test target '\(testTarget)' (it has: \(entries.isEmpty ? "none" : entries.joined(separator: ", ")))."
        return problem + " In an Xcode project, name the entry after the test target and list the files to mock: "
            + "[modules.\(key)] with sources = [\"App/**/*.swift\"]. Xcode doesn't tell the plugin which of the "
            + "project's targets a test depends on."
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
    configuration: String,
    derivedSourcesDir: URL,
    projectSources: [URL]
) throws -> [Command] {
    let configurationURL = projectDir.appending(path: "Cuckoofile.toml")
    let executable = try executableFactory("CuckooGenerator").url

    // Two products may share a target: its module is generated once.
    var seen: Set<String> = []
    let sourceModules = sourceModules.filter { seen.insert($0.name).inserted }
    return try sourceModules.map { sourceModule in
        let outputURL = derivedSourcesDir.appending(component: "GeneratedMocks_\(sourceModule.name).swift")
        // The Cuckoofile module mocks these files unless it lists its own `sources`.
        let sourcesListURL = derivedSourcesDir.appending(component: "Sources_\(sourceModule.name).txt")
        let listing = try sourcesArguments(sourceModule.listedSources, listURL: sourcesListURL)

        return .buildCommand(
            // SwiftPM names a command by its display name and arguments, so two test targets that depend on the same
            // module would get one command between them without the target's name here.
            displayName: "Generate Cuckoo mocks for \(sourceModule.name) in \(targetName)",
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
            // An entry that lists its own `sources` may read any of the project's files, so the command depends on all
            // of them; otherwise editing one wouldn't regenerate the mocks.
            inputFiles: [configurationURL] + listing.inputFiles + sourceModule.sources
                + (cuckoofileEntry(named: sourceModule.name, listsSourcesIn: configuration) ? projectSources : []),
            outputFiles: [outputURL]
        )
    }
}

/// Library and executable targets can be mocked: a test target may depend on, and `@testable import`, either.
private func isMockable(_ kind: ModuleKind) -> Bool {
    kind == .generic || kind == .executable
}

struct MissingCuckoofileError: Error, CustomStringConvertible {
    let directory: URL

    private var path: String {
        let path = directory.path(percentEncoded: false)
        return path.count > 1 && path.hasSuffix("/") ? String(path.dropLast()) : path
    }

    var description: String {
        "Cuckoo's build plugin needs a Cuckoofile.toml in \(path), the folder of the "
            + "package or Xcode project whose target uses the plugin. Add one with a [modules.<Name>] entry for each "
            + "module to mock; see Cuckoo's Getting Started article."
    }
}

/// The Cuckoofile next to the package or Xcode project, which the generator reads too. A missing one is an error
/// here, where it can say what to add, instead of a failed generator run.
private func readCuckoofile(in directory: URL) throws -> String {
    let url = directory.appending(path: "Cuckoofile.toml")
    guard FileManager.default.fileExists(atPath: url.path(percentEncoded: false)) else {
        throw MissingCuckoofileError(directory: directory)
    }
    return try String(contentsOf: url, encoding: .utf8)
}
