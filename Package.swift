// swift-tools-version:6.2

import PackageDescription

// Our own targets treat warnings as errors (roadmap Phase 2 item 6). SwiftPM ignores warning-control
// settings in packages fetched by URL, so this never fails the build of a project that depends on Cuckoo
// that way. A local path dependency does get the setting.
let warningsAsErrors: [SwiftSetting] = [.treatAllWarnings(as: .error)]

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
        // Any dependency changes must also be reflected in Generator/Project.swift.
        // Up to the next major release, so Cuckoo resolves alongside users' other packages. Packages still
        // at 0.x may break in a minor release, so they stop at the next minor one. The lockfiles pin exact revisions.
        .package(url: "https://github.com/kylef/Stencil", .upToNextMinor(from: "0.15.1")),
        .package(url: "https://github.com/swiftlang/swift-syntax", "600.0.0"..<"605.0.0"),
        // .package(url: "https://github.com/swiftlang/swift-format", "600.0.0"..<"605.0.0"),
        .package(url: "https://github.com/apple/swift-argument-parser", from: "1.8.2"),
        .package(url: "https://github.com/LebJe/TOMLKit", .upToNextMinor(from: "0.6.0")),
        .package(url: "https://github.com/tuist/XcodeProj", from: "9.17.6"),
        .package(url: "https://github.com/onevcat/Rainbow", from: "4.2.2"),
    ],
    targets: [
        .target(
            name: "Cuckoo",
            path: "Source",
            exclude: ["Info.plist"],
            swiftSettings: warningsAsErrors
        ),
        .executableTarget(
            name: "CuckooGenerator",
            dependencies: [
                .product(name: "Stencil", package: "Stencil"),
                // .product(name: "SwiftFormat", package: "swift-format"),
                .product(name: "SwiftSyntax", package: "swift-syntax"),
                .product(name: "SwiftParser", package: "swift-syntax"),
                .product(name: "ArgumentParser", package: "swift-argument-parser"),
                .product(name: "TOMLKit", package: "TOMLKit"),
                .product(name: "XcodeProj", package: "XcodeProj"),
                .product(name: "Rainbow", package: "Rainbow"),
            ],
            path: "Generator/Sources",
            swiftSettings: warningsAsErrors
        ),
        .testTarget(
            name: "CuckooGeneratorTests",
            dependencies: ["CuckooGenerator"],
            path: "Generator/Tests",
            exclude: ["Snapshots"],
            swiftSettings: warningsAsErrors
        ),
        // The runtime test suite, laid out the way users consume Cuckoo: the code under test is a plain
        // module, and the modular plugin generates one mocks file per module it depends on, configured in
        // Cuckoofile.toml. The SwiftUI fixture is its own module because a generated file shares one import list.
        .target(
            name: "CuckooTestSources",
            path: "Tests/Swift/Source",
            exclude: ["SwiftUI"],
            swiftSettings: warningsAsErrors
        ),
        .target(
            name: "CuckooTestSourcesSwiftUI",
            path: "Tests/Swift/Source/SwiftUI",
            swiftSettings: warningsAsErrors
        ),
        .target(
            name: "CuckooMocks",
            dependencies: ["Cuckoo", "CuckooTestSources", "CuckooTestSourcesSwiftUI"],
            path: "Tests/Swift/Mocks",
            swiftSettings: warningsAsErrors,
            plugins: ["CuckooPluginModular"]
        ),
        .testTarget(
            name: "CuckooTests",
            dependencies: ["Cuckoo", "CuckooTestSources", "CuckooMocks"],
            path: "Tests",
            exclude: ["Swift/Source", "Swift/Generated", "Swift/Mocks", "OCMock", "Info.plist"],
            swiftSettings: warningsAsErrors
        ),
        .plugin(
            name: "CuckooPluginSingleFile",
            capability: .buildTool(),
            dependencies: ["CuckooGenerator"],
            path: "Generator/Plugin/File"
        ),
        .plugin(
            name: "CuckooPluginModular",
            capability: .buildTool(),
            dependencies: ["CuckooGenerator"],
            path: "Generator/Plugin/Modular"
        ),
        // .plugin(
        //     name: "CuckooPluginIndividualFiles",
        //     capability: .buildTool(),
        //     dependencies: ["CuckooGenerator"],
        //     path: "Generator/Plugin/Directory"
        // ),
    ]
)
