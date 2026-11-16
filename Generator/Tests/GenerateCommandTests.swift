import ArgumentParser
import Foundation
import Testing
@testable import CuckooGenerator

/// The command line: where the Cuckoofile comes from, and a failed generation failing the run, so a build plugin
/// doesn't go on to compile stale or missing mocks.
@Suite
struct GenerateCommandTests {
    @Test
    func writesTheMocks() async throws {
        try await withPackage(output: "Mocks/GeneratedMocks.swift") { directory in
            try await GenerateCommand.parse(["--configuration", directory.appending(path: "Cuckoofile.toml").path(percentEncoded: false)]).run()
            let mocks = try String(contentsOf: directory.appending(path: "Mocks/GeneratedMocks.swift"), encoding: .utf8)
            #expect(mocks.contains("class MockGreeter"))
        }
    }

    @Test
    func failedWriteFailsTheRun() async throws {
        // The output's parent is a file, so its directory can't be created.
        try await withPackage(output: "Blocker/GeneratedMocks.swift") { directory in
            try "".write(to: directory.appending(path: "Blocker"), atomically: true, encoding: .utf8)
            await #expect(throws: ExitCode.failure) {
                try await GenerateCommand.parse(["--configuration", directory.appending(path: "Cuckoofile.toml").path(percentEncoded: false)]).run()
            }
        }
    }

    @Test
    func missingNamedConfigurationIsAnError() async throws {
        try await withPackage(output: "GeneratedMocks.swift") { directory in
            let missing = directory.appending(path: "Other.toml").path(percentEncoded: false)
            let error = await #expect(throws: (any Error).self) {
                try await GenerateCommand.parse(["--configuration", missing]).run()
            }
            #expect(String(describing: error).contains("Failed to read the Cuckoofile at '\(missing)'"))
        }
    }

    @Test
    func directoryOutputNamesTellSameNamedSourcesApart() {
        let names = GenerateCommand.outputNames(for: [
            "/p/Sources/A/User.swift",
            "/p/Sources/B/User.swift",
            "/p/Sources/A/Models/Item.swift",
            "/p/Sources/B/Models/Item.swift",
            "/p/Sources/Greeter.swift",
        ].map { Path($0) })
        #expect(names == ["A_User", "B_User", "A_Models_Item", "B_Models_Item", "Greeter"])
    }

    /// The header names the mocked file by its path from the Cuckoofile, wherever the generator runs.
    @Test
    func headerNamesTheFileFromTheCuckoofile() async throws {
        try await withPackage(output: "GeneratedMocks.swift") { directory in
            try await GenerateCommand.parse(["--configuration", directory.appending(path: "Cuckoofile.toml").path(percentEncoded: false)]).run(environment: [:])
            let mocks = try String(contentsOf: directory.appending(path: "GeneratedMocks.swift"), encoding: .utf8)
            #expect(mocks.contains("// MARK: - Mocks generated from file: 'App/Greeter.swift'"))
        }
    }

    /// A directory output gets one file per source file, named by `filenameFormat`.
    @Test
    func directoryOutputWritesAFilePerSource() async throws {
        try await withPackage(output: "Mocks", extraKeys: #"filenameFormat = "{}Mocks""#) { directory in
            try await GenerateCommand.parse(["--configuration", directory.appending(path: "Cuckoofile.toml").path(percentEncoded: false)]).run(environment: [:])
            let mocks = try String(contentsOf: directory.appending(path: "Mocks/GreeterMocks.swift"), encoding: .utf8)
            #expect(mocks.contains("class MockGreeter"))
        }
    }

    /// The build plugin's route: `PROJECT_DIR` finds the Cuckoofile, `CUCKOO_OVERRIDE_OUTPUT` replaces the output and
    /// `CUCKOO_MODULE_NAME` picks the module. A module the Cuckoofile doesn't have gets an empty file, so the build
    /// finds the output it declared.
    @Test
    func pluginEnvironmentPicksTheModuleAndOutput() async throws {
        try await withPackage(output: "Unused.swift") { directory in
            let output = directory.appending(path: "Derived/Mocks.swift")
            let environment = [
                "PROJECT_DIR": directory.path(percentEncoded: false),
                "CUCKOO_OVERRIDE_OUTPUT": output.path(percentEncoded: false),
                "CUCKOO_MODULE_NAME": "App",
            ]
            try await GenerateCommand.parse([]).run(environment: environment)
            #expect(try String(contentsOf: output, encoding: .utf8).contains("class MockGreeter"))
            #expect(!FileManager.default.fileExists(atPath: directory.appending(path: "Unused.swift").path(percentEncoded: false)))

            let missing = directory.appending(path: "Derived/Missing.swift")
            try await GenerateCommand.parse([]).run(environment: environment.merging([
                "CUCKOO_OVERRIDE_OUTPUT": missing.path(percentEncoded: false),
                "CUCKOO_MODULE_NAME": "Other",
            ]) { $1 })
            #expect(try String(contentsOf: missing, encoding: .utf8).isEmpty)
        }
    }

    /// The plugins run the generator once per module of the Cuckoofile; a module it doesn't have generates nothing,
    /// and the output it was given is left empty, so the build has the file it expects.
    @Test
    func aMissingModuleIsReportedAndLeavesAnEmptyOutput() async throws {
        try await withPackage(output: "GeneratedMocks.swift") { directory in
            let output = directory.appending(path: "Other/Mocks.swift")
            let printed = try await capturingOutput {
                try await GenerateCommand.parse([
                    "--configuration", directory.appending(path: "Cuckoofile.toml").path(percentEncoded: false),
                ]).run(environment: [
                    "CUCKOO_MODULE_NAME": "Other",
                    "CUCKOO_OVERRIDE_OUTPUT": output.path(percentEncoded: false),
                ])
            }
            #expect(printed.contains("No module named 'Other' found in Cuckoofile, skipping generation."))
            #expect(try String(contentsOf: output, encoding: .utf8) == "")
        }
    }

    /// What the run tells the user: the Cuckoofile's unknown keys, a source that matches nothing, what the crawler
    /// skips, a type declared twice, and the failures that fail the run.
    @Test
    func reportsWarningsAndErrors() async throws {
        try await withPackage(output: "GeneratedMocks.swift", extraKeys: "testableImport = []") { directory in
            try "protocol Greeter {\n    func wave()\n}\n\nclass Settings {\n    var store = makeStore()\n}\n"
                .write(to: directory.appending(path: "App/Duplicate.swift"), atomically: true, encoding: .utf8)
            let configuration = directory.appending(path: "Cuckoofile.toml")
            let contents = try String(contentsOf: configuration, encoding: .utf8)
            try contents.replacing(#"sources = ["App/*.swift"]"#, with: #"sources = ["App/*.swift", "Ap/*.swift"]"#)
                .write(to: configuration, atomically: true, encoding: .utf8)

            let printed = try await capturingOutput {
                try await GenerateCommand.parse(["--configuration", configuration.path(percentEncoded: false)]).run()
            }
            #expect(printed.contains("warning: cuckoo: \(configuration.path(percentEncoded: false)): "))
            #expect(printed.contains("testableImport"))
            #expect(printed.contains("warning: cuckoo: The source '") && printed.contains("matches no files"))
            #expect(printed.contains("Can't infer the type of property 'store'"))
            #expect(printed.contains("warning: cuckoo: 'Greeter' is declared in "))
        }
    }

    /// A run that fails says why on standard error before it exits.
    @Test
    func reportsTheFailure() async throws {
        try await withPackage(output: "Blocker/GeneratedMocks.swift") { directory in
            try "".write(to: directory.appending(path: "Blocker"), atomically: true, encoding: .utf8)
            let printed = await capturingOutput {
                await #expect(throws: ExitCode.failure) {
                    try await GenerateCommand.parse(["--configuration", directory.appending(path: "Cuckoofile.toml").path(percentEncoded: false)]).run()
                }
            }
            #expect(printed.contains("error: Failed to generate mocks for module App"))
        }
    }

    /// A source that can't be read fails the run, rather than leaving its mocks out without a word. Root reads any
    /// file, so the test is skipped there.
    @Test(.enabled(if: geteuid() != 0, "root can read any file"))
    func anUnreadableSourceFailsTheRun() async throws {
        try await withPackage(output: "GeneratedMocks.swift") { directory in
            let source = directory.appending(path: "App/Greeter.swift").path(percentEncoded: false)
            try FileManager.default.setAttributes([.posixPermissions: 0], ofItemAtPath: source)
            defer { try? FileManager.default.setAttributes([.posixPermissions: 0o644], ofItemAtPath: source) }
            let printed = await capturingOutput {
                await #expect(throws: ExitCode.failure) {
                    try await GenerateCommand.parse(["--configuration", directory.appending(path: "Cuckoofile.toml").path(percentEncoded: false)]).run()
                }
            }
            #expect(printed.contains("error: ") && printed.contains("Greeter.swift"))
        }
    }

    private func withPackage(output: String, extraKeys: String = "", _ body: (URL) async throws -> Void) async throws {
        let directory = FileManager.default.temporaryDirectory.appending(path: "CuckooCommand-\(UUID().uuidString)")
        defer { try? FileManager.default.removeItem(at: directory) }
        try FileManager.default.createDirectory(at: directory.appending(path: "App"), withIntermediateDirectories: true)
        try "protocol Greeter {\n    func greet() -> String\n}\n"
            .write(to: directory.appending(path: "App/Greeter.swift"), atomically: true, encoding: .utf8)
        try """
            [modules.App]
            output = "\(output)"
            testableImports = ["App"]
            sources = ["App/*.swift"]
            \(extraKeys)
            """
            .write(to: directory.appending(path: "Cuckoofile.toml"), atomically: true, encoding: .utf8)
        try await body(directory)
    }
}
