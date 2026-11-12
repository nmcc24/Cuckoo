import Foundation
import Testing
@testable import CuckooGenerator

/// Generates the mocks of `source`, as module `App` with headers omitted, and returns them as one text.
func generateMocks(source: String, moduleKeys: String = "", options: String = "") async throws -> String {
    let directory = FileManager.default.temporaryDirectory.appending(path: "CuckooOptions-\(UUID().uuidString)")
    try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
    defer { try? FileManager.default.removeItem(at: directory) }
    try source.write(to: directory.appending(path: "Source.swift"), atomically: true, encoding: .utf8)
    let modules = try Cuckoofile.modules(
        from: """
            [modules.App]
            sources = ["Source.swift"]
            output = "Mocks.swift"
            \(moduleKeys)

            [modules.App.options]
            omitHeaders = true
            \(options)
            """,
        configurationPath: Path(directory.appending(path: "Cuckoofile.toml").path(percentEncoded: false)),
        overriddenOutput: nil,
        requestedModuleName: nil
    )
    let module = try #require(modules.first)
    return try await Generator.generate(for: module, singleFileOutput: true, verbose: false)
        .map(\.contents)
        .joined(separator: "\n")
}
