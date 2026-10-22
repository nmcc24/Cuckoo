import Foundation
import Testing
#if canImport(CuckooGenerator)
// SwiftPM tests the executable target; the Tuist test target compiles the generator sources in directly.
@testable import CuckooGenerator
#endif

/// Golden-file tests: generate mocks for known inputs and compare them with the checked-in output in `Snapshots/`.
///
/// Set `CUCKOO_RECORD_SNAPSHOTS=1` to (re)write the snapshots instead of comparing them.
/// A missing snapshot is always written, and the test fails so new snapshots get reviewed.
@Suite
struct SnapshotTests {
    private static let repositoryRoot = URL(fileURLWithPath: #filePath)
        .deletingLastPathComponent()
        .deletingLastPathComponent()
        .deletingLastPathComponent()
    private static let snapshotsDirectory = URL(fileURLWithPath: #filePath)
        .deletingLastPathComponent()
        .appendingPathComponent("Snapshots")
    private static let swift6Fixtures: [String] = {
        let directory = repositoryRoot.appendingPathComponent("Fixtures/Swift6")
        let files = (try? FileManager.default.contentsOfDirectory(atPath: directory.path)) ?? []
        return files.filter { $0.hasSuffix(".swift") }.sorted()
    }()

    @Test(arguments: swift6Fixtures)
    func swift6Fixture(_ fileName: String) async throws {
        let contents = try await generate(sources: ["Fixtures/Swift6/\(fileName)"])
        try assertSnapshot(contents, named: "Swift6/\((fileName as NSString).deletingPathExtension)")
    }

    /// Mirrors the `Cuckoo` module in `Cuckoofile.toml`, which generates the mocks used by the runtime test suite.
    @Test
    func runtimeTestSources() async throws {
        let contents = try await generate(
            sources: ["Tests/Swift/Source/*.swift"],
            testableImports: ["Cuckoo"],
            exclude: ["ExcludedTestClass", "ExcludedProtocol"]
        )
        try assertSnapshot(contents, named: "RuntimeTests")
    }

    private func generate(
        sources: [String],
        testableImports: [String]? = nil,
        exclude: [String]? = nil
    ) async throws -> String {
        let module = try Module(
            name: "Snapshot",
            output: nil,
            configurationPath: Path(Self.repositoryRoot.appendingPathComponent("Cuckoofile.toml").path),
            dto: Module.DTO(
                imports: ["Foundation"],
                publicImports: nil,
                testableImports: testableImports,
                sources: sources,
                exclude: exclude,
                regex: nil,
                output: "unused.swift",
                filenameFormat: nil,
                options: Module.DTO.Options(
                    glob: true,
                    keepDocumentation: nil,
                    enableInheritance: nil,
                    protocolsOnly: nil,
                    omitHeaders: true
                ),
                xcodeproj: nil
            )
        )
        let files = try await Generator.generate(for: module, verbose: false)
        return files.map(\.contents).joined(separator: "\n\n") + "\n"
    }

    private func assertSnapshot(_ actual: String, named name: String, sourceLocation: SourceLocation = #_sourceLocation) throws {
        let url = Self.snapshotsDirectory.appendingPathComponent("\(name).snapshot")
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
        let expectedLines = expected.components(separatedBy: "\n")
        let actualLines = actual.components(separatedBy: "\n")
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
