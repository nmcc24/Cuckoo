import ProjectDescription
import ProjectDescriptionHelpers

let commonBuildSettingsBase: [String: SettingValue] = [
    "PRODUCT_NAME": .string("Cuckoo"),
    "SYSTEM_FRAMEWORK_SEARCH_PATHS": .string("$(PLATFORM_DIR)/Developer/Library/Frameworks"),
]
let testSourcesBuildSettingsBase: [String: SettingValue] = [
    "PRODUCT_NAME": .string("CuckooTestSources"),
]
let testSourcesSwiftUIBuildSettingsBase: [String: SettingValue] = [
    "PRODUCT_NAME": .string("CuckooTestSourcesSwiftUI"),
]
let mocksBuildSettingsBase: [String: SettingValue] = [
    "PRODUCT_NAME": .string("CuckooMocks"),
    "SYSTEM_FRAMEWORK_SEARCH_PATHS": .string("$(PLATFORM_DIR)/Developer/Library/Frameworks"),
]
// let objCBuildSettingsBase: [String: SettingValue] = [
//     "SWIFT_OBJC_BRIDGING_HEADER": .string("$(PROJECT_DIR)/OCMock/Cuckoo-BridgingHeader.h"),
// ]

func platformSet(platform: PlatformType) -> (targets: [Target], schemes: [Scheme]) {
    var targets: [Target] = []
    var schemes: [Scheme] = []

    // MARK: Swift targets.
    let defaultTarget = Target.target(
        name: "Cuckoo-\(platform)",
        destinations: platform.destinations,
        product: .framework,
        bundleId: "org.brightify.Cuckoo",
        deploymentTargets: platform.deploymentTargets,
        infoPlist: .default,
        sources: [
            "Source/**",
            // "OCMock/**",
        ],
        // headers: .headers(public: ["OCMock/**"]),
        dependencies: [
            .sdk(name: "XCTest", type: .framework, status: .optional),
            // .package(product: "OCMock"),
        ],
        settings: Settings.settings(base: commonBuildSettingsBase)
    )
    targets.append(defaultTarget)

    // The code the runtime tests mock lives in its own module, like a user's app code,
    // so the generated mocks and the tests reach it through an import.
    let testSourcesTarget = Target.target(
        name: "Cuckoo-\(platform)Tests-Sources",
        destinations: platform.destinations,
        product: .framework,
        bundleId: "org.brightify.Cuckoo.TestSources",
        deploymentTargets: platform.deploymentTargets,
        infoPlist: .default,
        sources: SourceFilesList.sourceFilesList(globs: [
            .glob("Tests/Swift/Source/**", excluding: ["Tests/Swift/Source/SwiftUI/**"]),
        ]),
        settings: Settings.settings(base: testSourcesBuildSettingsBase)
    )
    targets.append(testSourcesTarget)

    // SwiftUI declares common names such as `Namespace`, so its fixture is a module of its own,
    // with a mocks file of its own (Cuckoofile.toml). Package.swift has the same split.
    let testSourcesSwiftUITarget = Target.target(
        name: "Cuckoo-\(platform)Tests-SourcesSwiftUI",
        destinations: platform.destinations,
        product: .framework,
        bundleId: "org.brightify.Cuckoo.TestSourcesSwiftUI",
        deploymentTargets: platform.deploymentTargets,
        infoPlist: .default,
        sources: [
            "Tests/Swift/Source/SwiftUI/**",
        ],
        settings: Settings.settings(base: testSourcesSwiftUIBuildSettingsBase)
    )
    targets.append(testSourcesSwiftUITarget)

    let mocksTarget = Target.target(
        name: "Cuckoo-\(platform)Tests-Mocks",
        destinations: platform.destinations,
        product: .framework,
        bundleId: "org.brightify.Cuckoo",
        deploymentTargets: platform.deploymentTargets,
        infoPlist: .default,
        sources: [
            "Tests/Swift/Generated/*.swift",
            "Tests/Swift/Mocks/*.swift",
        ],
        scripts: [
            .pre(
                // Any changes in the mock generation phase should be reflected in `Generator/Project.swift` as well.
                script: """
                if [ "$GENERATE_TEST_MOCKS" = "NO" ] ; then exit; fi

                # Make sure the generator is up-to-date.
                echo 'Building generator.'
                "$PROJECT_DIR"/build_generator

                echo 'Generating mocks.'
                \([
                    #""$PROJECT_DIR"/Generator/bin/cuckoonator"#,
                    "--verbose",
                ].joined(separator: " \\\n\t"))
                """,
                name: "Generate mocks",
                basedOnDependencyAnalysis: false
            ),
        ],
        dependencies: [
            .target(defaultTarget),
            .target(testSourcesTarget),
            .target(testSourcesSwiftUITarget),
            .sdk(name: "XCTest", type: .framework, status: .optional),
        ],
        settings: Settings.settings(base: mocksBuildSettingsBase)
    )
    targets.append(mocksTarget)

    let defaultTestTarget = Target.target(
        name: "Cuckoo-\(platform)Tests",
        destinations: platform.destinations,
        product: .unitTests,
        bundleId: "org.brightify.Cuckoo",
        deploymentTargets: platform.deploymentTargets,
        infoPlist: .default,
        sources: SourceFilesList.sourceFilesList(globs: [
            .glob("Tests/Common/**"),
            // .glob("Tests/OCMock/**"),
            .glob("Tests/Swift/**", excluding: [
                "Tests/Swift/Generated/*.swift",
                "Tests/Swift/Mocks/*.swift",
                "Tests/Swift/Source/**",
            ]),
        ]),
        dependencies: [
            .target(defaultTarget),
            .target(testSourcesTarget),
            .target(mocksTarget),
            // .package(product: "OCMock"),
        ]
    )
    targets.append(defaultTestTarget)

    // MARK: Schemes.
    schemes.append(
        Scheme.scheme(
            name: defaultTarget.name,
            buildAction: BuildAction.buildAction(targets: [
                defaultTarget.reference,
                testSourcesTarget.reference,
                testSourcesSwiftUITarget.reference,
                mocksTarget.reference,
            ]),
            testAction: TestAction.targets([TestableTarget.testableTarget(target: defaultTestTarget.reference)])
        )
    )

    return (targets, schemes)
}

let (iOSTargets, iOSSchemes) = platformSet(platform: .iOS)
let (macOSTargets, macOSSchemes) = platformSet(platform: .macOS)
let (tvOSTargets, tvOSSchemes) = platformSet(platform: .tvOS)
let (watchOSTargets, watchOSSchemes) = platformSet(platform: .watchOS)

// MARK: project definition
let project = Project(
    name: "Cuckoo",
    options: .options(automaticSchemesOptions: .disabled, disableSynthesizedResourceAccessors: true),
    packages: [
        // .local(path: "OCMockWrapper"),
    ],
    settings: Settings.settings(base: [
        "GENERATE_TEST_MOCKS": "YES",
        // The runtime, the mocked test sources, their mocks and the tests form one package, as they
        // do under SwiftPM. Without a shared package name, Swift treats the tests' conformances of
        // `CuckooTestSources` types to Cuckoo protocols as retroactive and warns about them.
        "SWIFT_PACKAGE_NAME": "Cuckoo",
        // Cuckoo 3 supports only the Swift 6 language mode, as Package.swift does.
        "SWIFT_VERSION": "6.0",
        // Warnings in our own targets are errors, as in Package.swift. Dependencies build in their own projects.
        "SWIFT_TREAT_WARNINGS_AS_ERRORS": "YES",
        // Xcode's recommended settings, decided explicitly. The "Generate mocks" script builds the generator
        // with a nested xcodebuild and writes Tests/Swift/Generated, which the script sandbox would block.
        "ENABLE_USER_SCRIPT_SANDBOXING": "NO",
        // The targets are pure Swift, so there's no hand-written Clang module to verify.
        "ENABLE_MODULE_VERIFIER": "NO",
        // No String Catalogs.
        "STRING_CATALOG_GENERATE_SYMBOLS": "NO",
    ]),
    targets: iOSTargets + macOSTargets + tvOSTargets + watchOSTargets,
    schemes: iOSSchemes + macOSSchemes + tvOSSchemes + watchOSSchemes
)
