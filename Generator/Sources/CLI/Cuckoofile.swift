import Foundation
import TOMLKit

/// Reads `Cuckoofile.toml` into the modules to generate.
enum Cuckoofile {
    /// - Parameters:
    ///   - contents: The Cuckoofile's text.
    ///   - configurationPath: Where the Cuckoofile is; relative paths in it resolve against its folder.
    ///   - overriddenOutput: An output path that replaces every module's output (the build plugins set it).
    ///   - requestedModuleName: If set, only the module with this name is returned.
    static func modules(
        from contents: String,
        configurationPath: Path,
        overriddenOutput: String?,
        requestedModuleName: String?
    ) throws -> [Module] {
        var errorMessages: [String] = []
        var globalOutput: String? = overriddenOutput
        var allModules: [Module] = []
        let table = try TOMLTable(string: contents)

        // Sorting to make sure global properties are evaluated first to be available as fallbacks.
        let sortedTable = table.sorted { lhs, rhs in
            let (_, lhsValue) = lhs
            let (_, rhsValue) = rhs
            switch (lhsValue.type, rhsValue.type) {
            case (.table, .table):
                return true
            case (.table, _):
                return false
            case (_, .table):
                return true
            default:
                return true
            }
        }

        let decoder = TOMLDecoder()
        for (key, value) in sortedTable {
            switch key {
            case "output":
                if globalOutput == nil {
                    log(.verbose, message: "Global output:", globalOutput as Any)
                    globalOutput = value.string
                } else {
                    errorMessages.append("Multiple global `output` parameters. Behavior is undefined.")
                }
            case "modules":
                guard let modulesTable = value.table else {
                    throw ParseError.modulesMustBeTable
                }
                for (moduleName, innards) in modulesTable {
                    guard let moduleTable = innards.table else {
                        throw ParseError.modulesMustBeTable
                    }
                    let dto = try decoder.decode(Module.DTO.self, from: moduleTable)
                    do {
                        let module = try Module(
                            name: moduleName,
                            output: globalOutput,
                            overriddenOutput: overriddenOutput,
                            configurationPath: configurationPath,
                            dto: dto
                        )
                        log(.verbose, message: "Module \(moduleName):", module)
                        allModules.append(module)
                    } catch {
                        errorMessages.append(String(describing: error))
                    }
                }
            default:
                continue
            }
        }

        guard errorMessages.isEmpty else {
            throw ParseError.configurationErrors(details: errorMessages)
        }

        if let requestedModuleName {
            return allModules.filter { $0.name == requestedModuleName }
        }
        return allModules
    }

    enum ParseError: Error, CustomStringConvertible {
        case modulesMustBeTable
        case configurationErrors(details: [String])

        var description: String {
            switch self {
            case .modulesMustBeTable:
                return """
                Modules must be TOML tables. Define them as \("[modules.ModuleName]".bold) with properties beneath.
                """
            case .configurationErrors(let details):
                return """
                Cuckoofile contains errors:
                \(details.map { "\t- \($0)" }.joined(separator: "\n"))
                """
            }
        }
    }
}
