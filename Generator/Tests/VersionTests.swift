import Foundation
import Testing
#if canImport(CuckooGenerator)
// SwiftPM tests the executable target; the Tuist test target compiles the generator sources in directly.
@testable import CuckooGenerator
#endif

struct VersionTests {
    /// The `run` script compares the generator's `--version` with the `version` file and rebuilds on a mismatch (#601).
    @Test
    func generatorVersionMatchesVersionFile() throws {
        let versionFile = URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .appendingPathComponent("version")
        let expected = try String(contentsOf: versionFile, encoding: .utf8).trimmingCharacters(in: .whitespacesAndNewlines)
        #expect(version == expected)
    }
}
