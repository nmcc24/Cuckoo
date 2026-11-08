import Foundation
import Testing
@testable import CuckooGenerator

/// The generator writes a mocks file only when its contents change, so a build system that compares modification dates
/// doesn't recompile mocks the generator produced again unchanged.
@Suite
struct TextFileTests {
    @Test
    func unchangedContentsLeaveTheFileUntouched() throws {
        try withFile { url, file in
            try file.write("let a = 1\n")
            let past = Date(timeIntervalSince1970: 1_000_000)
            try FileManager.default.setAttributes([.modificationDate: past], ofItemAtPath: url.path(percentEncoded: false))

            try file.write("let a = 1\n")
            #expect(try modificationDate(of: url) == past)

            try file.write("let a = 2\n")
            #expect(try modificationDate(of: url) != past)
            #expect(try file.read() == "let a = 2\n")
        }
    }

    @Test
    func missingFileIsCreated() throws {
        try withFile { _, file in
            try file.write("")
            #expect(try file.read() == "")
        }
    }

    private func modificationDate(of url: URL) throws -> Date? {
        try FileManager.default.attributesOfItem(atPath: url.path(percentEncoded: false))[.modificationDate] as? Date
    }

    private func withFile(_ body: (URL, TextFile) throws -> Void) throws {
        let directory = FileManager.default.temporaryDirectory.appending(path: "CuckooTextFile-\(UUID().uuidString)")
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: directory) }
        let url = directory.appending(path: "GeneratedMocks.swift")
        try body(url, TextFile(path: Path(url.path(percentEncoded: false))))
    }
}
