import Foundation
import TOMLDecoder
import Rainbow

/// Reads `Cuckoofile.toml` into the modules to generate.
enum Cuckoofile {
    /// The top level of `Cuckoofile.toml`.
    private struct File: Decodable {
        /// The output of modules that don't set their own.
        let output: String?
        let modules: [String: Module.DTO]?
    }

    /// - Parameters:
    ///   - contents: The Cuckoofile's text.
    ///   - configurationPath: Where the Cuckoofile is; relative paths in it resolve against its folder.
    ///   - overriddenOutput: An output path that replaces every module's and the global output (the build plugins set it).
    ///   - requestedModuleName: If set, only the module with this name is returned.
    static func modules(
        from contents: String,
        configurationPath: Path,
        overriddenOutput: String?,
        requestedModuleName: String?
    ) throws -> [Module] {
        let file: File
        do {
            file = try TOMLDecoder().decode(File.self, from: contents)
        } catch {
            throw ParseError.unreadable(error)
        }

        var errorMessages: [String] = []
        var allModules: [Module] = []
        // Sorted, so modules are always generated in the same order.
        for (moduleName, dto) in (file.modules ?? [:]).sorted(by: { $0.key < $1.key }) {
            do {
                let module = try Module(
                    name: moduleName,
                    output: file.output,
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

        guard errorMessages.isEmpty else {
            throw ParseError.configurationErrors(details: errorMessages)
        }

        if let requestedModuleName {
            return allModules.filter { $0.name == requestedModuleName }
        }
        return allModules
    }

    enum ParseError: Error, CustomStringConvertible {
        case unreadable(any Error)
        case configurationErrors(details: [String])

        var description: String {
            switch self {
            case .unreadable(let error):
                return """
                Cuckoofile can't be read. Define modules as \("[modules.ModuleName]".bold) tables with properties beneath.
                \(error)
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
