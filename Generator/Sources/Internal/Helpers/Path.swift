#if canImport(FoundationEssentials)
import FoundationEssentials
#else
import Foundation
#endif

/// Minimal file system path, a portable replacement for FileKit's `Path`.
struct Path: Hashable, Sendable, CustomStringConvertible {
    static let separator = "/"

    static var current: Path {
        Path(FileManager.default.currentDirectoryPath)
    }

    let rawValue: String

    init(_ rawValue: String) {
        self.rawValue = rawValue
    }

    init(_ rawValue: String, expandingTilde: Bool) {
        self.rawValue = expandingTilde ? Path.expandingTilde(in: rawValue) : rawValue
    }

    var description: String {
        rawValue
    }

    var url: URL {
        URL(filePath: rawValue)
    }

    var isAbsolute: Bool {
        rawValue.hasPrefix(Path.separator)
    }

    var absolute: Path {
        isAbsolute ? standardized : (Path.current + self).standardized
    }

    /// The path with empty and `.` components removed, `..` resolved against the components before it, and no
    /// trailing separator. It reads the path's text only, never the file system.
    var standardized: Path {
        var components: [Substring] = []
        for component in rawValue.split(separator: "/") {
            switch component {
            case ".":
                continue
            case ".." where components.last.map({ $0 != ".." }) ?? isAbsolute:
                if !components.isEmpty { components.removeLast() }
            default:
                components.append(component)
            }
        }
        let joined = components.joined(separator: "/")
        return Path(isAbsolute ? "/" + joined : joined.isEmpty ? "." : joined)
    }

    var standardRawValue: String {
        standardized.rawValue
    }

    var parent: Path {
        let names = rawValue.split(separator: "/")
        guard names.count > 1 || (names.count == 1 && isAbsolute) else { return Path(isAbsolute ? "/" : ".") }
        let parent = names.dropLast().joined(separator: "/")
        return Path(isAbsolute ? "/" + parent : parent)
    }

    /// The root (`/`) of an absolute path, then each name.
    var components: [Path] {
        (isAbsolute ? [Path("/")] : []) + rawValue.split(separator: "/").map { Path(String($0)) }
    }

    var fileName: String {
        rawValue.split(separator: "/").last.map(String.init) ?? (isAbsolute ? "/" : "")
    }

    var fileNameWithoutExtension: String {
        Path.splittingExtension(of: fileName).name
    }

    var pathExtension: String {
        Path.splittingExtension(of: fileName).extension
    }

    var exists: Bool {
        FileManager.default.fileExists(atPath: rawValue)
    }

    var isDirectory: Bool {
        #if canImport(FoundationEssentials)
        var isDirectory = false
        return FileManager.default.fileExists(atPath: rawValue, isDirectory: &isDirectory) && isDirectory
        #else
        var isDirectory: ObjCBool = false
        return FileManager.default.fileExists(atPath: rawValue, isDirectory: &isDirectory) && isDirectory.boolValue
        #endif
    }

    func relative(to path: Path) -> Path {
        relative(to: path.rawValue)
    }

    func relative(to path: String) -> Path {
        isAbsolute ? self : Path(path) + self
    }

    func relative(to path: String?) -> Path? {
        if isAbsolute {
            return self
        } else {
            guard let path else { return nil }
            return Path(path) + self
        }
    }

    /// The deepest path that both `self` and `other` start with.
    func commonAncestor(_ other: Path) -> Path {
        let common = zip(absolute.components, other.absolute.components)
            .prefix { $0 == $1 }
            .map(\.0.rawValue)
        return common.dropFirst().reduce(Path(common.first ?? Path.separator)) { $0 + $1 }
    }

    /// Direct children (`searchDepth: 0`) or descendants up to `searchDepth` levels deeper that satisfy `condition`.
    func find(searchDepth: Int, condition: (Path) -> Bool) -> [Path] {
        let children = (try? FileManager.default.contentsOfDirectory(atPath: rawValue))?.sorted() ?? []
        return children.flatMap { name -> [Path] in
            let child = self + name
            let matches = condition(child) ? [child] : []
            guard searchDepth > 0, child.isDirectory else { return matches }
            return matches + child.find(searchDepth: searchDepth - 1, condition: condition)
        }
    }

    func createDirectory(withIntermediateDirectories: Bool) throws {
        try FileManager.default.createDirectory(atPath: rawValue, withIntermediateDirectories: withIntermediateDirectories)
    }

    static func + (lhs: Path, rhs: Path) -> Path {
        lhs + rhs.rawValue
    }

    static func + (lhs: Path, rhs: String) -> Path {
        guard !lhs.rawValue.isEmpty else { return Path(rhs) }
        let base = lhs.rawValue.hasSuffix("/") && lhs.rawValue != "/" ? String(lhs.rawValue.dropLast()) : lhs.rawValue
        let name = String(rhs.trimmingPrefix("/"))
        guard !name.isEmpty else { return Path(base) }
        return Path(base == "/" ? "/" + name : base + "/" + name)
    }

    static func + (lhs: String, rhs: Path) -> Path {
        Path(lhs) + rhs
    }

    /// `~` and `~/…` start from the user's home directory.
    private static func expandingTilde(in path: String) -> String {
        guard path == "~" || path.hasPrefix("~/") else { return path }
        let home = ProcessInfo.processInfo.environment["HOME"] ?? URL.homeDirectory.path(percentEncoded: false)
        return (Path(home) + String(path.dropFirst(2))).rawValue
    }

    /// A file name's extension is what follows its last `.`, unless that `.` starts the name, as in `.gitignore`.
    private static func splittingExtension(of fileName: String) -> (name: String, extension: String) {
        guard let dot = fileName.lastIndex(of: "."), dot != fileName.startIndex else { return (fileName, "") }
        return (String(fileName[..<dot]), String(fileName[fileName.index(after: dot)...]))
    }
}

/// UTF-8 text file at a `Path`, a portable replacement for FileKit's `TextFile`.
struct TextFile: Sendable, CustomStringConvertible {
    let path: Path

    init(path: Path) {
        self.path = path
    }

    var description: String {
        path.rawValue
    }

    func read() throws -> String {
        try String(contentsOfFile: path.rawValue, encoding: .utf8)
    }

    /// Writes `contents`, unless the file already holds exactly that. An untouched file keeps its modification date,
    /// so a build that regenerates unchanged mocks doesn't recompile them.
    func write(_ contents: String) throws {
        if (try? read()) == contents { return }
        try contents.write(toFile: path.rawValue, atomically: true, encoding: .utf8)
    }
}
