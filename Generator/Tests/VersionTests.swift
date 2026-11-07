import Foundation
import Testing
@testable import CuckooGenerator

struct VersionTests {
    /// The generator's `--version` reports the release in the `version` file (Brightify/Cuckoo#601).
    @Test
    func generatorVersionMatchesVersionFile() throws {
        let versionFile = URL(filePath: #filePath)
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .appending(path: "version")
        let expected = try String(contentsOf: versionFile, encoding: .utf8).trimmingCharacters(in: .whitespacesAndNewlines)
        #expect(version == expected)
    }
}
