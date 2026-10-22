import Foundation

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
        self.rawValue = expandingTilde ? NSString(string: rawValue).expandingTildeInPath : rawValue
    }

    var description: String {
        rawValue
    }

    var url: URL {
        URL(fileURLWithPath: rawValue)
    }

    var isAbsolute: Bool {
        rawValue.hasPrefix(Path.separator)
    }

    var absolute: Path {
        isAbsolute ? standardized : (Path.current + self).standardized
    }

    var standardized: Path {
        Path(NSString(string: rawValue).standardizingPath)
    }

    var standardRawValue: String {
        standardized.rawValue
    }

    var parent: Path {
        let parent = NSString(string: rawValue).deletingLastPathComponent
        return Path(parent.isEmpty ? "." : parent)
    }

    var components: [Path] {
        NSString(string: rawValue).pathComponents.map(Path.init)
    }

    var fileName: String {
        NSString(string: rawValue).lastPathComponent
    }

    var fileNameWithoutExtension: String {
        NSString(string: fileName).deletingPathExtension
    }

    var pathExtension: String {
        NSString(string: rawValue).pathExtension
    }

    var exists: Bool {
        FileManager.default.fileExists(atPath: rawValue)
    }

    var isDirectory: Bool {
        var isDirectory: ObjCBool = false
        return FileManager.default.fileExists(atPath: rawValue, isDirectory: &isDirectory) && isDirectory.boolValue
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
        return Path(NSString.path(withComponents: common.isEmpty ? [Path.separator] : common))
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
        return Path(NSString(string: lhs.rawValue).appendingPathComponent(rhs))
    }

    static func + (lhs: String, rhs: Path) -> Path {
        Path(lhs) + rhs
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

    func write(_ contents: String) throws {
        try contents.write(toFile: path.rawValue, atomically: true, encoding: .utf8)
    }
}
