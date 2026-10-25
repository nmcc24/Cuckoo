import ProjectDescription
import ProjectDescriptionHelpers

let target = Target.target(
    name: "Cuckoonator",
    destinations: .macOS,
    product: .commandLineTool,
    productName: "cuckoonator",
    bundleId: "Cuckoonator",
    deploymentTargets: .macOS("14.0"),
    sources: "Sources/**",
    dependencies: [
        "Stencil",
        "SwiftSyntax",
        "SwiftParser",
        "ArgumentParser",
        "TOMLDecoder",
        "Rainbow",
    ].map { TargetDependency.package(product: $0) }
)

let testTarget = Target.target(
    name: "CuckoonatorTests",
    destinations: .macOS,
    product: .unitTests,
    bundleId: "CuckoonatorTests",
    deploymentTargets: target.deploymentTargets,
    sources: SourceFilesList.sourceFilesList(globs: [
        // TODO: This is wrong but testing CLI is not supported, must separate generator into CLI and internal targets.
        target.sources?.globs,
        ["Tests/**"],
    ].compactMap { $0 }.flatMap { $0 }),
    // TODO: This is wrong but testing CLI is not supported, must separate generator into CLI and internal targets.
    dependencies: target.dependencies
)

// MARK: project definition
let project = Project(
    name: "Generator",
    options: .options(automaticSchemesOptions: .disabled, disableSynthesizedResourceAccessors: true),
    packages: [
        // Any dependency changes must also be reflected in ../Package.swift, with the same requirements.
        .package(url: "https://github.com/kylef/Stencil", .upToNextMinor(from: "0.15.1")),
        .package(url: "https://github.com/swiftlang/swift-syntax", "600.0.0"..<"605.0.0"),
        // .package(url: "https://github.com/swiftlang/swift-format", "600.0.0"..<"605.0.0"),
        .package(url: "https://github.com/apple/swift-argument-parser", .upToNextMajor(from: "1.8.2")),
        .package(url: "https://github.com/dduan/TOMLDecoder", .upToNextMinor(from: "0.4.5")),
        .package(url: "https://github.com/onevcat/Rainbow", .upToNextMajor(from: "4.2.2")),
    ],
    settings: .settings(base: [
        // Warnings in the generator are errors, as in ../Package.swift. Dependencies build in their own projects.
        "SWIFT_TREAT_WARNINGS_AS_ERRORS": "YES",
        // Xcode's recommended settings, decided explicitly, as in ../Project.swift.
        "ENABLE_USER_SCRIPT_SANDBOXING": "NO",
        "ENABLE_MODULE_VERIFIER": "YES",
        "STRING_CATALOG_GENERATE_SYMBOLS": "YES",
    ]),
    targets: [
        target,
        testTarget,
    ],
    schemes: [
        Scheme.scheme(
            name: "Generator",
            buildAction: BuildAction.buildAction(
                targets: ["Cuckoonator"],
                postActions: [
                    ExecutionAction.executionAction(
                        title: "Copy executable",
                        scriptText: #"\cp "$BUILT_PRODUCTS_DIR/$EXECUTABLE_NAME" "$PROJECT_DIR/bin/cuckoonator""#,
                        target: "Cuckoonator"
                    )
                ],
                runPostActionsOnFailure: false
            ),
            testAction: TestAction.targets([TestableTarget.testableTarget(target: testTarget.reference)]),
            runAction: RunAction.runAction(
                executable: "Cuckoonator",
                arguments: Arguments.arguments(
                    environmentVariables: [
                        "PROJECT_DIR": Environment.projectDir.requireString(message: "TUIST_PROJECT_DIR environment property is required."),
                    ],
                    launchArguments: [
                        // Any changes here should be reflected in `../Project.swift` as well.
                        LaunchArgument.launchArgument(name: "--configuration ./Cuckoofile", isEnabled: true),
                        LaunchArgument.launchArgument(name: "--verbose", isEnabled: true),
                    ]
                )
            )
        ),
    ]
)
