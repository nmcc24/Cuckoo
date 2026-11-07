import Foundation

extension String {
    var nilIfEmpty: String? {
        isEmpty ? nil : self
    }
}

extension String {
    /// A type written as `Parent<String, Int>`, without its generic arguments: `Parent`.
    var withoutGenericArguments: String {
        guard let openingBracket = firstIndex(of: "<") else { return self }
        return self[..<openingBracket].trimmedSpaces
    }

    /// A type's top-level generic arguments: `["String", "[Int: Bool]"]` for `Parent<String, [Int: Bool]>`.
    var genericArguments: [String] {
        guard let openingBracket = firstIndex(of: "<"), hasSuffix(">") else { return [] }
        var arguments: [String] = []
        var current = ""
        var depth = 0
        for character in self[index(after: openingBracket)..<index(before: endIndex)] {
            switch character {
            case "<", "[", "(":
                depth += 1
            case ">", "]", ")":
                depth -= 1
            case "," where depth == 0:
                arguments.append(current.trimmedSpaces)
                current = ""
                continue
            default:
                break
            }
            current.append(character)
        }
        arguments.append(current.trimmedSpaces)
        return arguments
    }
}
