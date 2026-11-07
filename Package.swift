// swift-tools-version:6.2

import PackageDescription

// Our own targets treat warnings as errors (roadmap Phase 2 item 6). SwiftPM ignores warning-control
// settings in packages fetched by URL, so this never fails the build of a project that depends on Cuckoo
// that way. A local path dependency does get the setting.
// They also adopt the Swift 7 upcoming features that only change what compiles (roadmap Phase 3.5).
// The behaviour-changing ones are covered by the CI job that adds them, comma-separated,
// through `CUCKOO_UPCOMING_FEATURES`.
let swiftSettings: [SwiftSetting] = [
    .treatAllWarnings(as: .error),
    .enableUpcomingFeature("ExistentialAny"),
    .enableUpcomingFeature("MemberImportVisibility"),
    .enableUpcomingFeature("InternalImportsByDefault"),
    .enableUpcomingFeature("ImmutableWeakCaptures"),
] + (Context.environment["CUCKOO_UPCOMING_FEATURES"] ?? "")
    .split(separator: ",")
    .map { .enableUpcomingFeature(String($0)) }

/// Where the plugins' generator comes from. Master builds it from source. The release workflow's tagged commit sets
/// `prebuiltGenerator` to the release's `artifactbundle` (roadmap Phase 5 item 2), so plugin users don't compile
/// swift-syntax; `scripts/smoke-test-artifactbundle.sh` sets a local bundle to test one before it's released.
enum GeneratorBinary {
    case remote(url: String, checksum: String)
    case local(path: String)
}

let prebuiltGenerator: GeneratorBinary? = nil

/// The plugins find the generator by its executable's name, `CuckooGenerator`, which the bundle's executable has too.
let generator: Target.Dependency = prebuiltGenerator == nil ? "CuckooGenerator" : "CuckooGeneratorBinary"
let generatorBinaryTargets: [Target] = switch prebuiltGenerator {
case .remote(let url, let checksum): [.binaryTarget(name: "CuckooGeneratorBinary", url: url, checksum: checksum)]
case .local(let path): [.binaryTarget(name: "CuckooGeneratorBinary", path: path)]
case nil: []
}

let package = Package(
    name: "Cuckoo",
    platforms: [
        .iOS("17.0"),
        .tvOS("17.0"),
        .macOS("14.0"),
        .watchOS("10.0"),
    ],
    products: [
        .library(
            name: "Cuckoo",
            targets: ["Cuckoo"]
        ),
        .executable(
            name: "CuckooGenerator",
            targets: ["CuckooGenerator"]
        ),
        .plugin(
            name: "CuckooPluginSingleFile",
            targets: ["CuckooPluginSingleFile"]
        ),
        .plugin(
            name: "CuckooPluginModular",
            targets: ["CuckooPluginModular"]
        ),
        // FIXME: Currently unusable because Xcode doesn't allow using prebuild commands with executable targets
        // .plugin(
        //     name: "CuckooPluginIndividualFiles",
        //     targets: ["CuckooPluginIndividualFiles"]
        // ),
    ],
    dependencies: [
        // Up to the next major release, so Cuckoo resolves alongside users' other packages. Packages still
        // at 0.x may break in a minor release, so they stop at the next minor one. The lockfiles pin exact revisions.
        .package(url: "https://github.com/swiftlang/swift-syntax", "602.0.0"..<"605.0.0"),
        // .package(url: "https://github.com/swiftlang/swift-format", "600.0.0"..<"605.0.0"),
        .package(url: "https://github.com/apple/swift-argument-parser", from: "1.8.2"),
        .package(url: "https://github.com/dduan/TOMLDecoder", .upToNextMinor(from: "0.4.5")),
    ],
    targets: [
        .target(
            name: "Cuckoo",
            path: "Source",
            exclude: ["Info.plist"],
            swiftSettings: swiftSettings
        ),
        .executableTarget(
            name: "CuckooGenerator",
            dependencies: [
                // .product(name: "SwiftFormat", package: "swift-format"),
                .product(name: "SwiftSyntax", package: "swift-syntax"),
                .product(name: "SwiftParser", package: "swift-syntax"),
                .product(name: "SwiftBasicFormat", package: "swift-syntax"),
                .product(name: "ArgumentParser", package: "swift-argument-parser"),
                .product(name: "TOMLDecoder", package: "TOMLDecoder"),
            ],
            path: "Generator/Sources",
            swiftSettings: swiftSettings
        ),
        .testTarget(
            name: "CuckooGeneratorTests",
            dependencies: [
                "CuckooGenerator",
                .product(name: "SwiftSyntax", package: "swift-syntax"),
                .product(name: "SwiftParser", package: "swift-syntax"),
            ],
            path: "Generator/Tests",
            exclude: ["Snapshots"],
            swiftSettings: swiftSettings
        ),
        // The runtime test suite, laid out the way users consume Cuckoo: the code under test is a plain
        // module, and the modular plugin generates one mocks file per module it depends on, configured in
        // Cuckoofile.toml.
        .target(
            name: "CuckooTestSources",
            path: "Tests/Swift/Source",
            swiftSettings: swiftSettings
        ),
        // Its Cuckoofile entry lists no `sources`, so the plugin's `--sources-list` picks its files.
        .target(
            name: "CuckooPluginTestSources",
            path: "Tests/Plugin/Source",
            swiftSettings: swiftSettings
        ),
        .target(
            name: "CuckooMocks",
            dependencies: ["Cuckoo", "CuckooTestSources", "CuckooPluginTestSources"],
            path: "Tests/Swift/Mocks",
            swiftSettings: swiftSettings,
            plugins: ["CuckooPluginModular"]
        ),
        .testTarget(
            name: "CuckooTests",
            dependencies: ["Cuckoo", "CuckooTestSources", "CuckooPluginTestSources", "CuckooMocks"],
            path: "Tests",
            exclude: ["Swift/Source", "Swift/Mocks", "Plugin/Source", "SingleFile", "Info.plist"],
            swiftSettings: swiftSettings
        ),
        // The single-file plugin generates every Cuckoofile module into one file, as build-script users get it,
        // which merges the imports of all the sources.
        .target(
            name: "CuckooSingleFileMocks",
            dependencies: ["Cuckoo", "CuckooTestSources", "CuckooPluginTestSources"],
            path: "Tests/SingleFile/Mocks",
            swiftSettings: swiftSettings,
            plugins: ["CuckooPluginSingleFile"]
        ),
        .testTarget(
            name: "CuckooSingleFileTests",
            dependencies: ["Cuckoo", "CuckooTestSources", "CuckooPluginTestSources", "CuckooSingleFileMocks"],
            path: "Tests/SingleFile",
            exclude: ["Mocks"],
            swiftSettings: swiftSettings
        ),
        .plugin(
            name: "CuckooPluginSingleFile",
            capability: .buildTool(),
            dependencies: [generator],
            path: "Generator/Plugin/File"
        ),
        .plugin(
            name: "CuckooPluginModular",
            capability: .buildTool(),
            dependencies: [generator],
            path: "Generator/Plugin/Modular"
        ),
        // .plugin(
        //     name: "CuckooPluginIndividualFiles",
        //     capability: .buildTool(),
        //     dependencies: ["CuckooGenerator"],
        //     path: "Generator/Plugin/Directory"
        // ),
    ] + generatorBinaryTargets
)
