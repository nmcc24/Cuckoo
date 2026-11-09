#if canImport(FoundationEssentials)
import FoundationEssentials
#else
import Foundation
#endif
#if canImport(Glibc)
import Glibc
#elseif canImport(Musl)
import Musl
#else
import Darwin
#endif

//  Adapted from https://gist.github.com/blakemerryman/76312e1cbf8aec248167
/**
 Finds files on the file system using pattern matching.
 */
final class Glob: Collection {
    /**
     * Different glob implementations have different behaviors, so the behavior of this
     * implementation is customizable.
     */
    struct Behavior {
        // If true then a globstar ("**") causes matching to be done recursively in subdirectories.
        // If false then "**" is treated the same as "*"
        let supportsGlobstar: Bool

        // If true the results from the directory where the globstar is declared will be included as well.
        // For example, with the pattern "dir/**/*.ext" the fie "dir/file.ext" would be included if this
        // property is true, and would be omitted if it's false.
        let includesFilesFromRootOfGlobstar: Bool

        // If false then the results will not include directory entries. This does not affect recursion depth.
        let includesDirectoriesInResults: Bool

        // If false and the last characters of the pattern are "**/" then only directories are returned in the results.
        let includesFilesInResultsIfTrailingSlash: Bool
    }

    static let defaultBehavior = Glob.Behavior(
        supportsGlobstar: true,
        includesFilesFromRootOfGlobstar: true,
        includesDirectoriesInResults: false,
        includesFilesInResultsIfTrailingSlash: false
    )

    private var isDirectoryCache = [String: Bool]()

    let behavior: Behavior
    var paths = [String]()
    var startIndex: Int { return paths.startIndex }
    var endIndex: Int   { return paths.endIndex   }

    init(pattern: String, behavior: Behavior = Glob.defaultBehavior) {

        self.behavior = behavior

        var adjustedPattern = pattern
        let hasTrailingGlobstarSlash = pattern.hasSuffix("**/")
        var includeFiles = !hasTrailingGlobstarSlash

        if behavior.includesFilesInResultsIfTrailingSlash {
            includeFiles = true
            if hasTrailingGlobstarSlash {
                // Grab the files too.
                adjustedPattern += "*"
            }
        }

        let patterns = behavior.supportsGlobstar ? expandGlobstar(pattern: adjustedPattern) : [adjustedPattern]

        for pattern in patterns {
            var gt = glob_t()
            if executeGlob(pattern: pattern, gt: &gt) {
                populateFiles(gt: gt, includeFiles: includeFiles)
            }

            globfree(&gt)
        }

        paths = Set(paths).sorted()

        clearCaches()
    }

    // MARK: - Private

    private var globalFlags = GLOB_TILDE | GLOB_BRACE | GLOB_MARK

    private func executeGlob(pattern: UnsafePointer<CChar>, gt: UnsafeMutablePointer<glob_t>) -> Bool {
        return 0 == glob(pattern, globalFlags, nil, gt)
    }

    private func expandGlobstar(pattern: String) -> [String] {
        guard pattern.contains("**") else {
            return [pattern]
        }

        var parts = pattern.split(separator: "**", omittingEmptySubsequences: false).map(String.init)
        let firstPart = parts.removeFirst()
        let lastPart = parts.joined(separator: "**")

        // A wildcard before the globstar, as in `Modules/*/Sources/**/*.swift`, picks several roots to recurse into.
        guard !firstPart.contains(where: { "*?[{".contains($0) }) else {
            return matchingDirectories(of: firstPart).flatMap { root in
                expandGlobstar(pattern: root + "**" + lastPart)
            }
        }

        var results = [String]()
        var directories: [String]
        do {
            directories = try FileManager.default.subpathsOfDirectory(atPath: firstPart).compactMap { subpath in
                let fullPath = (Path(firstPart) + subpath).rawValue
                return Path(fullPath).isDirectory ? fullPath : nil
            }
        } catch {
            directories = []
            printToStandardError("warning: Can't list the directory '\(firstPart)': \(error)\n")
        }

        if behavior.includesFilesFromRootOfGlobstar {
            // Check the base directory for the glob star as well.
            directories.insert(firstPart, at: 0)

            // Include the globstar root directory ("dir/") in a pattern like "dir/**" or "dir/**/"
            if lastPart.isEmpty {
                results.append(firstPart)
            }
        }

        let remainingPattern = lastPart.isEmpty ? "*" : lastPart
        for directory in directories {
            let partiallyResolvedPattern = (Path(directory) + remainingPattern).rawValue
            results.append(contentsOf: expandGlobstar(pattern: partiallyResolvedPattern))
        }

        return results
    }

    /// The directories a pattern without a globstar matches, each with a trailing slash.
    private func matchingDirectories(of pattern: String) -> [String] {
        var gt = glob_t()
        defer { globfree(&gt) }
        guard executeGlob(pattern: pattern, gt: &gt) else { return [] }
        return (0..<Int(gt.gl_pathc)).compactMap { index in
            // GLOB_MARK ends each directory with a slash.
            gt.gl_pathv[index].flatMap { String(validatingCString: $0) }.flatMap { $0.hasSuffix("/") ? $0 : nil }
        }
    }

    private func isDirectory(path: String) -> Bool {
        var isDirectory = isDirectoryCache[path]
        if let isDirectory = isDirectory {
            return isDirectory
        }

        isDirectory = Path(path).isDirectory
        isDirectoryCache[path] = isDirectory!

        return isDirectory!
    }

    private func clearCaches() {
        isDirectoryCache.removeAll()
    }

    private func populateFiles(gt: glob_t, includeFiles: Bool) {
        let includeDirectories = behavior.includesDirectoriesInResults

        for i in 0..<Int(gt.gl_pathc) {
            if let path = String(validatingCString: gt.gl_pathv[i]!) {
                if !includeFiles || !includeDirectories {
                    let isDirectory = self.isDirectory(path: path)
                    if (!includeFiles && !isDirectory) || (!includeDirectories && isDirectory) {
                        continue
                    }
                }

                paths.append(path)
            }
        }
    }

    // MARK: - Subscript Support

    subscript(i: Int) -> String {
        return paths[i]
    }

    func index(after i: Int) -> Int {
        return i + 1
    }
}
