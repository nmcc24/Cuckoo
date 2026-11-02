import Foundation
import Testing
@testable import CuckooGenerator

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
