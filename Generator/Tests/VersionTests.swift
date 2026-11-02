import Foundation
import Testing
@testable import CuckooGenerator

struct VersionTests {
    /// The generator's `--version` reports the release in the `version` file (Brightify/Cuckoo#601).
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
