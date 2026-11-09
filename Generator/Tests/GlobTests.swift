import Foundation
import Testing
@testable import CuckooGenerator

/// Source patterns: a globstar recurses into every subdirectory, also below a wildcard.
@Suite
struct GlobTests {
    @Test
    func globstarBelowAWildcard() throws {
        let directory = FileManager.default.temporaryDirectory.appending(path: "CuckooGlob-\(UUID().uuidString)")
        defer { try? FileManager.default.removeItem(at: directory) }
        let files = [
            "Modules/A/Sources/Top.swift",
            "Modules/A/Sources/Nested/Deep.swift",
            "Modules/B/Sources/Other.swift",
            "Modules/B/Resources/Skipped.swift",
        ]
        for file in files {
            let url = directory.appending(path: file)
            try FileManager.default.createDirectory(at: url.deletingLastPathComponent(), withIntermediateDirectories: true)
            try "".write(to: url, atomically: true, encoding: .utf8)
        }
        let root = directory.path(percentEncoded: false)
        let matches = Glob(pattern: "\(root)/Modules/*/Sources/**/*.swift").map { Path($0).standardRawValue }
        #expect(matches == [
            "Modules/A/Sources/Nested/Deep.swift",
            "Modules/A/Sources/Top.swift",
            "Modules/B/Sources/Other.swift",
        ].map { Path("\(root)/\($0)").standardRawValue })
    }
}
