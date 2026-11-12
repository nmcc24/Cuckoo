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

    /// A source that stands for no file is reported, since it usually means a typo or a moved directory.
    @Test
    func sourcesMatchingNothingAreReported() throws {
        let directory = FileManager.default.temporaryDirectory.appending(path: "CuckooGlob-\(UUID().uuidString)")
        defer { try? FileManager.default.removeItem(at: directory) }
        try FileManager.default.createDirectory(at: directory.appending(path: "App"), withIntermediateDirectories: true)
        try "".write(to: directory.appending(path: "App/Model.swift"), atomically: true, encoding: .utf8)

        func warnings(sources: String, options: String = "") throws -> [String] {
            let modules = try Cuckoofile.modules(
                from: """
                    [modules.App]
                    sources = \(sources)
                    output = "Mocks.swift"

                    [modules.App.options]
                    \(options)
                    """,
                configurationPath: Path(directory.appending(path: "Cuckoofile.toml").path(percentEncoded: false)),
                overriddenOutput: nil,
                requestedModuleName: nil
            )
            return try Generator.expandSources(of: #require(modules.first)).warnings
        }

        let root = directory.path(percentEncoded: false)
        #expect(try warnings(sources: #"["App/*.swift", "Ap/*.swift"]"#) == [
            "The source '\(Path("\(root)/Ap/*.swift"))' of module App matches no files.",
        ])
        #expect(try warnings(sources: #"["App/Model.swift", "App/Gone.swift"]"#, options: "glob = false") == [
            "The source '\(Path("\(root)/App/Gone.swift"))' of module App doesn't exist.",
        ])
    }
}
