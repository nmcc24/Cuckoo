import Foundation

struct FileHeaderHandler {
    static func header(for file: FileRepresentation, timestamp: String?) -> String {
        let path = getRelativePath(to: file)
        return [
            "// MARK: - Mocks generated from file: '\(path)'",
            timestamp.map { "at \($0)" },
        ]
        .compactMap { $0 }
        .joined(separator: " ")
    }

    static func imports(
        for file: FileRepresentation,
        imports: [String],
        publicImports: [String],
        testableImports: [String],
        publicModules: Set<String>
    ) -> String {
        func access(_ module: String) -> String {
            publicModules.contains(module) ? "public " : ""
        }
        let unconditionalImports = OrderedSet(
            file.imports.filter { $0.compilationConditions.isEmpty }.map(\.description) + imports
        ).values
        .filter { !testableImports.contains($0) }
        // An import inside `#if` keeps its condition, so the mocks build wherever the source does.
        let conditionalImports = file.imports
            .filter { !$0.compilationConditions.isEmpty }
            .filter { !unconditionalImports.contains($0.description) && !testableImports.contains($0.description) }
            .map { "#if \($0.compilationConditions.joined(separator: " && "))\n\(access($0.description))import \($0)\n#endif" }
        return [
            !publicImports.contains("Cuckoo") ? ["\(access("Cuckoo"))import Cuckoo"] : [],
            unconditionalImports.map { "\(access($0))import \($0)" },
            conditionalImports,
            publicImports.map { "public import \($0)" },
            testableImports.map { "@testable \(access($0))import \($0)" },
        ]
        .flatMap { $0 }
        .joined(separator: "\n")
    }

    private static func getRelativePath(to file: FileRepresentation) -> String {
        let path = file.file.path.absolute
        let base = path.commonAncestor(Path.current)
        let components = path.components.suffix(from: base.components.endIndex)
        let result = components.map { $0.rawValue }.joined(separator: Path.separator)
        let difference = Path.current.components.endIndex - base.components.endIndex
        return (0..<difference).reduce(result) { acc, _ in ".." + Path.separator + acc }
    }
}
