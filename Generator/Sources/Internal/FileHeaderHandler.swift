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

    /// The imports of the mocks of `files`, each once: one file's, or every file's when they're joined into one.
    static func imports(
        for files: [FileRepresentation],
        imports: [String],
        publicImports: [String],
        testableImports: [String],
        publicModules: Set<String>,
        typesByModule: [String: [TopLevelType]] = [:]
    ) -> String {
        // `@_spi` groups per module: what the sources import, and for the mocked modules, every group the mocked
        // declarations use, because a testable import doesn't make SPI visible.
        var spiGroups: [String: [String]] = [:]
        func add(_ groups: [String], to module: String) {
            for group in groups where !spiGroups[module, default: []].contains(group) {
                spiGroups[module, default: []].append(group)
            }
        }
        let sourceImports = files.flatMap(\.imports)
        for sourceImport in sourceImports {
            add(sourceImport.spiGroups, to: sourceImport.description)
        }
        let declaredGroups = declaredSPIGroups(in: files.flatMap(\.tokens))
        for module in testableImports where module != "Cuckoo" {
            add(declaredGroups, to: module)
        }
        func spi(_ module: String) -> String {
            spiGroups[module, default: []].map { "@_spi(\($0)) " }.joined()
        }
        func access(_ module: String) -> String {
            publicModules.contains(module) ? "public " : ""
        }
        // A module imports once, with the strongest form asked for: testable, then public, then plain.
        let unconditionalImports = OrderedSet(
            ["Cuckoo"] + sourceImports.filter { $0.compilationConditions.isEmpty }.map(\.description) + imports
        ).values
        .filter { !testableImports.contains($0) && !publicImports.contains($0) }
        // An import inside `#if` keeps its condition, so the mocks build wherever the source does. Imports under the
        // same condition share one block.
        var importsByCondition: [(condition: String, imports: OrderedSet<String>)] = []
        for sourceImport in sourceImports where !sourceImport.compilationConditions.isEmpty {
            let module = sourceImport.description
            guard !unconditionalImports.contains(module) && !testableImports.contains(module) && !publicImports.contains(module) else { continue }
            let condition = sourceImport.compilationConditions.joined(separator: " && ")
            let line = "\(spi(module))\(access(module))import \(module)"
            if let index = importsByCondition.firstIndex(where: { $0.condition == condition }) {
                importsByCondition[index].imports.insert(line)
            } else {
                importsByCondition.append((condition, OrderedSet([line])))
            }
        }
        let conditionalImports = importsByCondition.map { condition, imports in
            (["#if \(condition)"] + imports.values + ["#endif"]).joined(separator: "\n")
        }
        // A scoped import of each type the module declares beats every whole-module import, so the type's name
        // means it in the mocks even where another imported module declares the same name. Without a testable
        // import, only the public types are visible.
        let scopedImports = (testableImports + publicImports + unconditionalImports).flatMap { module -> [String] in
            let testable = testableImports.contains(module)
            let prefix = testable ? "\(spi(module))@testable \(access(module))"
                : publicImports.contains(module) ? "\(spi(module))public " : "\(spi(module))\(access(module))"
            return (typesByModule[module] ?? [])
                .filter { testable || $0.accessibility == .public || $0.accessibility == .open }
                .map { type in
                    let line = "\(prefix)import \(type.kind) \(module).\(type.name)"
                    guard !type.compilationConditions.isEmpty else { return line }
                    return "#if \(type.compilationConditions.joined(separator: " && "))\n\(line)\n#endif"
                }
        }
        return [
            unconditionalImports.map { "\(spi($0))\(access($0))import \($0)" },
            conditionalImports,
            publicImports.map { "\(spi($0))public import \($0)" },
            testableImports.map { "\(spi($0))@testable \(access($0))import \($0)" },
            scopedImports,
        ]
        .flatMap { $0 }
        .joined(separator: "\n")
    }

    /// The `@_spi` groups of the declarations in `tokens` and of their members, in order of appearance.
    private static func declaredSPIGroups(in tokens: [any Token]) -> [String] {
        var groups: [String] = []
        func collect(_ token: any Token) {
            for group in ((token as? any HasAttributes)?.attributes ?? []).compactMap(\.spiGroup) where !groups.contains(group) {
                groups.append(group)
            }
            (token as? any HasMembers)?.members.forEach(collect)
        }
        tokens.forEach(collect)
        return groups
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
