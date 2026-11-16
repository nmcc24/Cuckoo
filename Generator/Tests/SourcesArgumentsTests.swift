import Foundation
import Testing

/// How the plugins pass a target's files to the generator (`Generator/Plugin/SourcesArguments.swift`, linked here).
@Suite
struct SourcesArgumentsTests {
    private func temporaryList() -> URL {
        FileManager.default.temporaryDirectory.appending(path: "CuckooSourcesList-\(UUID().uuidString)/sources.txt")
    }

    @Test
    func aShortListingIsPassedInline() throws {
        let list = temporaryList()
        let (arguments, inputFiles) = try sourcesArguments(
            [ListedSource(swiftModule: "App", url: URL(filePath: "/p/A.swift")), ListedSource(swiftModule: nil, url: URL(filePath: "/p/B.swift"))],
            listURL: list
        )
        #expect(arguments == ["--source", "App\t/p/A.swift", "--source", "\t/p/B.swift"])
        #expect(inputFiles.isEmpty)
        #expect(!FileManager.default.fileExists(atPath: list.path(percentEncoded: false)))
    }

    /// An empty listing, which `--source` can't express, and one over 256 KiB go in a file.
    @Test
    func anEmptyOrLongListingGoesInAFile() throws {
        let empty = temporaryList()
        defer { try? FileManager.default.removeItem(at: empty.deletingLastPathComponent()) }
        let (emptyArguments, emptyInputs) = try sourcesArguments([], listURL: empty)
        #expect(emptyArguments == ["--sources-list", empty.path(percentEncoded: false)])
        #expect(emptyInputs == [empty])
        #expect(try String(contentsOf: empty, encoding: .utf8) == "")

        let long = temporaryList()
        defer { try? FileManager.default.removeItem(at: long.deletingLastPathComponent()) }
        let path = "/p/" + String(repeating: "a", count: 1000) + ".swift"
        let sources = (0..<300).map { ListedSource(swiftModule: "App", url: URL(filePath: path + "\($0)")) }
        let (arguments, inputs) = try sourcesArguments(sources, listURL: long)
        #expect(arguments == ["--sources-list", long.path(percentEncoded: false)])
        #expect(inputs == [long])
        #expect(try String(contentsOf: long, encoding: .utf8).split(separator: "\n").count == 300)
    }

    /// An unchanged list isn't rewritten, so the build doesn't rerun the generator.
    @Test
    func anUnchangedListIsNotRewritten() throws {
        let list = temporaryList()
        defer { try? FileManager.default.removeItem(at: list.deletingLastPathComponent()) }
        _ = try sourcesArguments([], listURL: list)
        let past = Date(timeIntervalSince1970: 1_000_000)
        try FileManager.default.setAttributes([.modificationDate: past], ofItemAtPath: list.path(percentEncoded: false))
        _ = try sourcesArguments([], listURL: list)
        let modified = try FileManager.default.attributesOfItem(atPath: list.path(percentEncoded: false))[.modificationDate] as? Date
        #expect(modified == past)
    }
}
