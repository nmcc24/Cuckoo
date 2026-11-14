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
            configuration: try readCuckoofile(in: context.package.directoryURL),
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
        // say nothing. The line reader can misread a Cuckoofile, so finding no entries at all isn't an error: the
        // generator, which parses the TOML, reports what's wrong with it.
        let entries = cuckoofileModuleNames(in: configuration)
        let generated = Set(sourceModules.map(\.name) + [target.displayName])
        if !entries.isEmpty, entries.isDisjoint(with: generated) {
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
            : "The Cuckoofile has no entry for the Xcode test target '\(testTarget)' (it has: \(entries.joined(separator: ", ")))."
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

/// The names of the Cuckoofile's entries: `App` for `[modules.App]`, `[modules.App.options]`, a dotted
/// `modules.App.sources = …` key, or an `App = { … }` key in a `[modules]` table. Like
/// ``cuckoofileEntry(named:listsSourcesIn:)``, it reads the lines rather than the TOML.
func cuckoofileModuleNames(in configuration: String) -> Set<String> {
    var names: Set<String> = []
    for line in cuckoofileKeyLines(configuration) where line.key.count >= 2 && line.key[0] == "modules" {
        names.insert(line.key[1])
    }
    return names
}

/// Whether the Cuckoofile entry `name` lists its own `sources`, in a `[modules.name]` table, a
/// `[modules.name.sources]` table, a dotted `modules.name.sources` or `sources.Module` key or an inline table. It
/// reads the lines rather than the TOML, since a plugin can't depend on a parser; a wrong yes only costs a
/// generator run.
func cuckoofileEntry(named name: String, listsSourcesIn configuration: String) -> Bool {
    let sources = ["modules", name, "sources"]
    return cuckoofileKeyLines(configuration).contains { line in
        // An inline table, `App = { sources = [...] }`, counts if it mentions `sources` at all.
        line.key.starts(with: sources) || (line.key == ["modules", name] && line.value.contains("sources"))
    }
}

/// Each table header and key of a Cuckoofile, as the full key it defines (a key inside a table is prefixed with
/// the table's name), and the text after a key's `=`.
func cuckoofileKeyLines(_ configuration: String) -> [(key: [String], value: Substring)] {
    var lines: [(key: [String], value: Substring)] = []
    var table: [String] = []
    var multilineDelimiter: String?
    for line in configuration.split(whereSeparator: \.isNewline) {
        // Lines inside a multi-line string are its text, not keys.
        if let delimiter = multilineDelimiter {
            if line.contains(delimiter) {
                multilineDelimiter = nil
            }
            continue
        }
        // Only a delimiter in the line's TOML counts, not one in a comment.
        let code = withoutComment(line)
        for delimiter in [String(repeating: "\"", count: 3), "'''"] where code.ranges(of: delimiter).count == 1 {
            multilineDelimiter = delimiter
        }
        let line = line.drop { $0 == " " || $0 == "\t" }
        if line.first == "[" {
            table = tomlKeySegments(line.drop { $0 == "[" }, endingAt: "]")
            lines.append((table, ""))
        } else if line.first != "#", let (key, value) = tomlKeyAndValue(line) {
            lines.append((table + key, value))
        }
    }
    return lines
}

/// A line up to its `#` comment, if it has one outside quotes.
private func withoutComment(_ line: Substring) -> Substring {
    var quote: Character?
    for index in line.indices {
        let character = line[index]
        if let open = quote {
            if character == open { quote = nil }
        } else if character == "\"" || character == "'" {
            quote = character
        } else if character == "#" {
            return line[..<index]
        }
    }
    return line
}

/// The segments of a TOML key that runs until `terminator` outside quotes: `modules."My App".options` is
/// `["modules", "My App", "options"]`. Dots outside quotes separate segments, whitespace outside quotes is
/// dropped, and a quoted segment keeps its contents.
func tomlKeySegments(_ text: Substring, endingAt terminator: Character) -> [String] {
    var segments: [String] = []
    var current = ""
    var quote: Character?
    for character in text {
        if let open = quote {
            if character == open {
                quote = nil
            } else {
                current.append(character)
            }
            continue
        }
        switch character {
        case terminator:
            return segments + [current]
        case "\"", "'":
            quote = character
        case ".":
            segments.append(current)
            current = ""
        case " ", "\t":
            continue
        default:
            current.append(character)
        }
    }
    return segments + [current]
}

/// A `key = value` line's key segments and the text after its `=`, or nil when the line has no `=` outside quotes.
private func tomlKeyAndValue(_ line: Substring) -> (key: [String], value: Substring)? {
    var quote: Character?
    for index in line.indices {
        let character = line[index]
        if let open = quote {
            if character == open { quote = nil }
        } else if character == "\"" || character == "'" {
            quote = character
        } else if character == "=" {
            return (tomlKeySegments(line[..<index], endingAt: "="), line[line.index(after: index)...])
        }
    }
    return nil
}
