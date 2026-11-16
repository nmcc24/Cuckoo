import Foundation
import Testing
@testable import CuckooGenerator

/// Golden-file tests: generate mocks for known inputs and compare them with the checked-in output in `Snapshots/`.
///
/// Set `CUCKOO_RECORD_SNAPSHOTS=1` to (re)write the snapshots instead of comparing them.
/// A missing snapshot is always written, and the test fails so new snapshots get reviewed.
@Suite
struct SnapshotTests {
    private static let repositoryRoot = URL(filePath: #filePath)
        .deletingLastPathComponent()
        .deletingLastPathComponent()
        .deletingLastPathComponent()
    private static let snapshotsDirectory = URL(filePath: #filePath)
        .deletingLastPathComponent()
        .appending(path: "Snapshots")
    private static let swift6Fixtures: [String] = {
        let directory = repositoryRoot.appending(path: "Fixtures/Swift6")
        let files = (try? FileManager.default.contentsOfDirectory(atPath: directory.path(percentEncoded: false))) ?? []
        return files.filter { $0.hasSuffix(".swift") }.sorted()
    }()

    /// The fixtures and their snapshots match one to one. The fixtures are listed at run time, so a moved directory
    /// would leave the parameterized test with no cases, which passes; a snapshot with no fixture is left from a
    /// deleted or renamed one.
    @Test
    func everySwift6FixtureHasItsSnapshot() throws {
        let directory = Self.snapshotsDirectory.appending(path: "Swift6")
        let snapshots = try FileManager.default.contentsOfDirectory(atPath: directory.path(percentEncoded: false))
            .filter { $0.hasSuffix(".snapshot") }
            .map { String($0.dropLast(".snapshot".count)) }
        let fixtures = Self.swift6Fixtures.map { String($0.dropLast(".swift".count)) }
        #expect(!fixtures.isEmpty)
        #expect(snapshots.sorted() == fixtures)
    }

    @Test(arguments: swift6Fixtures)
    func swift6Fixture(_ fileName: String) async throws {
        let contents = try await generate(sources: ["Fixtures/Swift6/\(fileName)"])
        try assertSnapshot(contents, named: "Swift6/\(fileName.dropLast(".swift".count))")
    }

    /// The `CuckooTestSources` module of the repository's `Cuckoofile.toml`, which generates the mocks the runtime test
    /// suite uses, read from the file itself so the snapshot follows it.
    @Test
    func runtimeTestSources() async throws {
        let configuration = Self.repositoryRoot.appending(path: "Cuckoofile.toml")
        let module = try #require(try Cuckoofile.modules(
            from: String(contentsOf: configuration, encoding: .utf8),
            configurationPath: Path(configuration.path(percentEncoded: false)),
            overriddenOutput: "unused.swift",
            requestedModuleName: "CuckooTestSources"
        ).first)
        let files = try await Generator.generate(for: module, singleFileOutput: true, verbose: false)
        try assertSnapshot(files.map(\.contents).joinedByBlankLines(), named: "RuntimeTests")
    }

    /// Doc comments are copied onto mock members unless `keepDocumentation = false`.
    @Test
    func documentation() async throws {
        let sources = ["Tests/Swift/Source/TestedProtocol.swift", "Tests/Swift/Source/UnicodeTestProtocol.swift"]
        let kept = try await generate(sources: sources, keepDocumentation: true)
        try assertSnapshot(kept, named: "Documentation")

        let stripped = try await generate(sources: sources, keepDocumentation: false)
        // The templates emit `/// MARK:` comments of their own.
        let docLines = stripped.lines.filter { $0.contains("///") && !$0.contains("/// MARK:") }
        #expect(docLines.isEmpty)
    }

    /// Under `InternalImportsByDefault`, a public mock needs public imports of the modules its declaration names,
    /// and a public import that nothing public uses is a warning. A file joined into one output shares one access
    /// level per module, or the compiler warns about the conflicting ones.
    @Test
    func publicImportsFollowPublicMocks() async throws {
        let directory = FileManager.default.temporaryDirectory.appending(path: "CuckooPublicImports-\(UUID().uuidString)")
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: directory) }
        try "public import Foundation\n\npublic protocol PublicService {\n    func url() -> URL\n}\n"
            .write(to: directory.appending(path: "A.swift"), atomically: true, encoding: .utf8)
        try "import Dispatch\n\nprotocol InternalService {\n    func run()\n}\n"
            .write(to: directory.appending(path: "B.swift"), atomically: true, encoding: .utf8)
        let sources = [directory.appending(path: "*.swift").path(percentEncoded: false)]

        let separate = try await generateFiles(sources: sources, testableImports: ["Sources"], singleFileOutput: false)
        #expect(separate.count == 2)
        let publicFile = separate.first { $0.contains("PublicService") } ?? ""
        let internalFile = separate.first { $0.contains("InternalService") } ?? ""
        for line in ["public import Cuckoo", "public import Foundation", "@testable public import Sources"] {
            #expect(publicFile.contains("\n\(line)\n") || publicFile.hasPrefix("\(line)\n"), "\(line)")
        }
        #expect(!internalFile.contains("public import"))

        let joined = try await generateFiles(sources: sources, testableImports: ["Sources"], singleFileOutput: true)
        let importLines = Set(joined.joined().lines.filter { $0.hasPrefix("import ") || $0.contains(" import ") })
        #expect(importLines == [
            "public import Cuckoo", "public import Foundation", "import Dispatch", "@testable public import Sources",
        ])
    }

    private func generate(
        sources: [String],
        testableImports: [String]? = nil,
        exclude: [String]? = nil,
        keepDocumentation: Bool? = nil
    ) async throws -> String {
        try await generateFiles(
            sources: sources,
            testableImports: testableImports,
            exclude: exclude,
            keepDocumentation: keepDocumentation,
            singleFileOutput: true
        )
        .joinedByBlankLines()
    }

    private func generateFiles(
        sources: [String] = [],
        testableImports: [String]? = nil,
        exclude: [String]? = nil,
        keepDocumentation: Bool? = nil,
        singleFileOutput: Bool
    ) async throws -> [String] {
        let module = try Module(
            name: "Snapshot",
            output: nil,
            configurationPath: Path(Self.repositoryRoot.appending(path: "Cuckoofile.toml").path(percentEncoded: false)),
            dto: Module.DTO(
                imports: ["Foundation"],
                publicImports: nil,
                testableImports: testableImports,
                sources: .paths(sources),
                exclude: exclude,
                regex: nil,
                globalActors: nil,
                output: "unused.swift",
                filenameFormat: nil,
                options: Module.DTO.Options(
                    keepDocumentation: keepDocumentation,
                    protocolsOnly: nil,
                    mockPrefix: nil,
                    mockSuffix: nil,
                    defaultIsolation: nil
                ),
                xcodeproj: nil
            )
        )
        let files = try await Generator.generate(for: module, singleFileOutput: singleFileOutput, verbose: false)
        return files.map(\.contents)
    }

    private func assertSnapshot(_ actual: String, named name: String, sourceLocation: SourceLocation = #_sourceLocation) throws {
        let url = Self.snapshotsDirectory.appending(path: "\(name).snapshot")
        #expect(!actual.contains("\n\n\n"), "\(name) has two blank lines in a row", sourceLocation: sourceLocation)
        let isRecording = ProcessInfo.processInfo.environment["CUCKOO_RECORD_SNAPSHOTS"] == "1"
        let expected = try? String(contentsOf: url, encoding: .utf8)

        if isRecording || expected == nil {
            try FileManager.default.createDirectory(at: url.deletingLastPathComponent(), withIntermediateDirectories: true)
            try actual.write(to: url, atomically: true, encoding: .utf8)
            if expected == nil && !isRecording {
                Issue.record("Recorded new snapshot \(name). Review it and re-run.", sourceLocation: sourceLocation)
            }
            return
        }

        guard let expected, expected != actual else { return }
        let expectedLines = expected.lines
        let actualLines = actual.lines
        let line = zip(expectedLines, actualLines).enumerated().first { $1.0 != $1.1 }?.offset ?? min(expectedLines.count, actualLines.count)
        let expectedLine = line < expectedLines.count ? expectedLines[line] : "<end of file>"
        let actualLine = line < actualLines.count ? actualLines[line] : "<end of file>"
        Issue.record(
            """
            Snapshot \(name) differs at line \(line + 1). Re-run with CUCKOO_RECORD_SNAPSHOTS=1 if the change is intended.
            expected: \(expectedLine)
              actual: \(actualLine)
            """,
            sourceLocation: sourceLocation
        )
    }
}
