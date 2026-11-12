import Foundation

// Shared by `CuckooPlugin` and the test-only `CuckooSingleFileTestPlugin`, which links this file: a plugin can't
// depend on a library target.

/// A file for the generator's source listing, and the Swift module it belongs to where that's certain.
struct ListedSource {
    let swiftModule: String?
    let url: URL
}

/// The generator's arguments for a target's files: one `--source` per file, so the command needs no file of its own
/// and a deleted plugin directory regenerates on the next build. A long listing, which could pass the system's limit
/// on command-line length, goes in a `--sources-list` file instead, as does an empty one, which `--source` can't express.
func sourcesArguments(_ sources: [ListedSource], listURL: URL) throws -> (arguments: [String], inputFiles: [URL]) {
    let lines = sources.map { "\($0.swiftModule ?? "")\t\($0.url.path(percentEncoded: false))" }
    if !lines.isEmpty && lines.reduce(0, { $0 + $1.utf8.count + 10 }) <= maximumInlineSourcesLength {
        return (lines.flatMap { ["--source", $0] }, [])
    }
    try writeSourcesList(lines, to: listURL)
    return (["--sources-list", listURL.path(percentEncoded: false)], [listURL])
}

/// Well under macOS's 1 MiB limit on a command's arguments and environment together.
private let maximumInlineSourcesLength = 256 * 1024

/// Writes the source files for the generator's `--sources-list`, one per line: the Swift module, a tab and the path.
/// An unchanged list isn't rewritten, so the build only reruns the generator when the target's files change.
private func writeSourcesList(_ lines: [String], to url: URL) throws {
    let contents = Data(lines.map { "\($0)\n" }.joined().utf8)
    guard (try? Data(contentsOf: url)) != contents else { return }
    try FileManager.default.createDirectory(at: url.deletingLastPathComponent(), withIntermediateDirectories: true)
    try contents.write(to: url, options: .atomic)
}
