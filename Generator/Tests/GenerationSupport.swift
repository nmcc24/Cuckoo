import Foundation
import Testing
@testable import CuckooGenerator

/// Generates the mocks of `source`, as module `App`, and returns them as one text. `sources` is the module's
/// `sources` key, for a test that names the file's Swift module.
func generateMocks(
    source: String,
    sources: String = #"["Source.swift"]"#,
    moduleKeys: String = "",
    options: String = ""
) async throws -> String {
    let directory = FileManager.default.temporaryDirectory.appending(path: "CuckooOptions-\(UUID().uuidString)")
    try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
    defer { try? FileManager.default.removeItem(at: directory) }
    try source.write(to: directory.appending(path: "Source.swift"), atomically: true, encoding: .utf8)
    let modules = try Cuckoofile.modules(
        from: """
            [modules.App]
            sources = \(sources)
            output = "Mocks.swift"
            \(moduleKeys)

            [modules.App.options]
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

extension String {
    /// The text's lines, an empty one included where it starts, ends or has two line breaks in a row.
    var lines: [String] {
        split(separator: "\n", omittingEmptySubsequences: false).map(String.init)
    }
}

/// What `body` logs and prints to standard error, at `level` and above.
func capturingOutput(level: Logger.LogLevel = .info, _ body: () async throws -> Void) async rethrows -> String {
    let output = CapturedOutput()
    try await Logger.$level.withValue(level) {
        try await Logger.$capture.withValue({ output.append($0) }) {
            try await body()
        }
    }
    return output.text
}

/// What `body` logs and prints to standard error, at `level` and above.
func capturingOutput(level: Logger.LogLevel = .info, _ body: () throws -> Void) rethrows -> String {
    let output = CapturedOutput()
    try Logger.$level.withValue(level) {
        try Logger.$capture.withValue({ output.append($0) }, operation: body)
    }
    return output.text
}

/// The lock guards `captured`, as the runtime's `Locked` does: `Mutex` needs macOS 15.
private final class CapturedOutput: @unchecked Sendable {
    private let lock = NSLock()
    private var captured = ""

    func append(_ text: String) {
        lock.withLock { captured += text }
    }

    var text: String {
        lock.withLock { captured }
    }
}
