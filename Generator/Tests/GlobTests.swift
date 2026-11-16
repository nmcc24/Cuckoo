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

    /// A globstar skips hidden directories, as a shell's does: `.build` holds the dependencies' sources. A pattern can
    /// still name a hidden directory itself.
    @Test
    func globstarSkipsHiddenDirectories() throws {
        let directory = FileManager.default.temporaryDirectory.appending(path: "CuckooGlob-\(UUID().uuidString)")
        defer { try? FileManager.default.removeItem(at: directory) }
        let files = [
            "App/Service.swift",
            "App/Feature/View.swift",
            "App/.build/checkouts/Dependency/Sources/Dependency.swift",
            "App/.git/hooks/Hook.swift",
            "App/Feature/.hidden/Skipped.swift",
        ]
        for file in files {
            let url = directory.appending(path: file)
            try FileManager.default.createDirectory(at: url.deletingLastPathComponent(), withIntermediateDirectories: true)
            try "".write(to: url, atomically: true, encoding: .utf8)
        }
        let root = directory.path(percentEncoded: false)
        let matches = Glob(pattern: "\(root)/App/**/*.swift").map { Path($0).standardRawValue }.sorted()
        #expect(matches == [
            "App/Feature/View.swift",
            "App/Service.swift",
        ].map { Path("\(root)/\($0)").standardRawValue })
        let named = Glob(pattern: "\(root)/App/.build/**/*.swift").map { Path($0).standardRawValue }
        #expect(named == [Path("\(root)/App/.build/checkouts/Dependency/Sources/Dependency.swift").standardRawValue])
        let namedAfter = Glob(pattern: "\(root)/App/**/.hidden/*.swift").map { Path($0).standardRawValue }
        #expect(namedAfter == [Path("\(root)/App/Feature/.hidden/Skipped.swift").standardRawValue])
    }

    /// A symbolic link to a directory is searched, but not walked into, so a link cycle can't recurse, and one into
    /// the directory the globstar already searches is skipped.
    @Test
    func globstarSearchesLinkedDirectoriesOnce() throws {
        let directory = FileManager.default.temporaryDirectory.appending(path: "CuckooGlob-\(UUID().uuidString)")
        defer { try? FileManager.default.removeItem(at: directory) }
        for file in ["App/Service.swift", "Other/Linked.swift", "Other/Deeper/Skipped.swift"] {
            let url = directory.appending(path: file)
            try FileManager.default.createDirectory(at: url.deletingLastPathComponent(), withIntermediateDirectories: true)
            try "".write(to: url, atomically: true, encoding: .utf8)
        }
        let root = directory.path(percentEncoded: false)
        try FileManager.default.createSymbolicLink(atPath: "\(root)/App/Link", withDestinationPath: "../Other")
        try FileManager.default.createSymbolicLink(atPath: "\(root)/App/Loop", withDestinationPath: ".")
        let matches = Set(Glob(pattern: "\(root)/App/**/*.swift").map { Path($0).standardRawValue })
        #expect(matches.contains(Path("\(root)/App/Service.swift").standardRawValue))
        #expect(matches.contains(Path("\(root)/App/Link/Linked.swift").standardRawValue))
        #expect(!matches.contains(Path("\(root)/App/Link/Deeper/Skipped.swift").standardRawValue))
        // `Loop` links back into the directory the globstar searches, whose files are listed once already.
        #expect(!matches.contains { $0.contains("/Loop/") })
    }

    /// A source that stands for no file is reported, since it usually means a typo or a moved directory.
    @Test
    func sourcesMatchingNothingAreReported() throws {
        let directory = FileManager.default.temporaryDirectory.appending(path: "CuckooGlob-\(UUID().uuidString)")
        defer { try? FileManager.default.removeItem(at: directory) }
        try FileManager.default.createDirectory(at: directory.appending(path: "App"), withIntermediateDirectories: true)
        try "".write(to: directory.appending(path: "App/Model.swift"), atomically: true, encoding: .utf8)

        func warnings(sources: String) throws -> [String] {
            let modules = try Cuckoofile.modules(
                from: """
                    [modules.App]
                    sources = \(sources)
                    output = "Mocks.swift"
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
        #expect(try warnings(sources: #"["App/Model.swift", "App/Gone.swift"]"#) == [
            "The source '\(Path("\(root)/App/Gone.swift"))' of module App matches no files.",
        ])
    }

    /// A directory a globstar can't list is reported and skipped, and the rest of the pattern still matches. Root
    /// reads any directory, so the test is skipped there (the Linux containers run as root).
    @Test(.enabled(if: geteuid() != 0, "root can list any directory"))
    func anUnreadableDirectoryIsReported() throws {
        let directory = FileManager.default.temporaryDirectory.appending(path: "CuckooGlob-\(UUID().uuidString)")
        let locked = directory.appending(path: "App/Locked")
        try FileManager.default.createDirectory(at: locked, withIntermediateDirectories: true)
        try "".write(to: directory.appending(path: "App/Model.swift"), atomically: true, encoding: .utf8)
        try FileManager.default.setAttributes([.posixPermissions: 0], ofItemAtPath: locked.path(percentEncoded: false))
        defer {
            try? FileManager.default.setAttributes([.posixPermissions: 0o755], ofItemAtPath: locked.path(percentEncoded: false))
            try? FileManager.default.removeItem(at: directory)
        }
        #expect((try? FileManager.default.contentsOfDirectory(atPath: locked.path(percentEncoded: false))) == nil)

        let root = directory.path(percentEncoded: false)
        var matches: [String] = []
        let printed = capturingOutput {
            matches = Glob(pattern: "\(root)/App/**/*.swift").map { Path($0).standardRawValue }
        }
        #expect(matches == [Path("\(root)/App/Model.swift").standardRawValue])
        #expect(printed.hasPrefix("warning: Can't list the directory '"))
        #expect(printed.contains("Locked"))
    }

    /// Sources are always globs: a file whose name has a glob character is matched with `?` in its place.
    @Test
    func aNameWithGlobCharactersIsMatchedWithAQuestionMark() throws {
        let directory = FileManager.default.temporaryDirectory.appending(path: "CuckooGlob-\(UUID().uuidString)")
        defer { try? FileManager.default.removeItem(at: directory) }
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        try "".write(to: directory.appending(path: "Odd[1].swift"), atomically: true, encoding: .utf8)
        let root = directory.path(percentEncoded: false)
        let matches = Glob(pattern: "\(root)/Odd?1?.swift").map { Path($0).standardRawValue }
        #expect(matches == [Path("\(root)/Odd[1].swift").standardRawValue])
    }
}
